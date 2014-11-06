################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- srun_wrapper -----------------------#
# Description: wrapper for shell automation
#   SRUN for nsh transport
# Sequence:
#  Automation engine preprocesses target script with ERB and keywords
#  Adds to params[SS_srun_wrapper]
# FIXME - how do we get the content path for deployed artifacts?
# NOTE: we are grouping servers by platform and using properties from the first assuming they are the same
#  this is an optimization, otherwise we lose parallel deployment

#---------------------- Declarations -----------------------#
require 'timeout'

#---------------------- Methods ----------------------------#

# Runs the action script on the remote targets
#
# ==== Attributes
#
# * +action+ - text of action script
# ==== Returns
#
# * command_run hash {stdout => <results>, stderr => any errors, pid => process id, status => exit_code}
def run!(action, options = {})
  message_box "Executing Remote Script"
  servers = get_option(options,"servers", @p.server_list.keys)
  target_path = get_option(options,"target_path", windows? ? "/C/Windows/temp" : "/tmp")
  wrapper_script = get_option(options,"wrapper_script", nil)
  max_time = get_option(options,"max_time", @timeout)
  payload = get_option(options,"payload", nil)
  log "Targets:       #{servers.join(",")}"
  log "Target Path:   #{target_path}"
  log "Max time(sec): #{max_time}"
  log "Script Details:"
  log "\t Platform:  #{@platform}"
  log "\t Transport: #{@platform_info["transport"]}"
  log "\t Payload:  #{payload}" if payload
  if action.include?("\n")
    action_name = temp_action_name
    action_path = create_temp_action(action, action_name)
  else
    action_name = File.basename(action)
    action_path = action
  end
  log "\t Source:    #{action_path}"
  payload_path = payload ? transport_payload(payload, target_path, servers) : nil
  brpd_compatibility(payload_path, target_path) if payload
  pre_process_action(action_path, payload_path)
  wrapper_path = wrapper_script(wrapper_script, action_path, target_path, servers) if wrapper_script
  script_path = wrapper_script.nil? ? action_path : wrapper_path
  result = @nsh.script_exec(servers, script_path, target_path, {"raw_result" => true, "timeout" => max_time})
  message_box "Script Results"
  log display_result(result)
  res = remove_temp_files(action_path, target_path, servers) if wrapper_script && !@debug
  result
end

# Servers in params need to be filtered by OS
def get_platform_servers(os_platform)
  servers = get_server_list(@params)
  result = servers.select{|k,v| v["os_platform"].downcase =~ /#{os_platform}/ }
end

def get_platform_temp_dir(os_plaform)
  os = "linux"
  os = "windows" if os_platform.downcase =~ /win/
  DEFAULT_TEMP_DIR[os]
end
  
def get_keyword_items
  keywords = ["RPM_PARAMS_FILTER","RPM_SRUN_WRAPPER","RPM_INCLUDE"]
  result = {}
  keywords.each do |keyword|
    reg = /\$\$\{#{keyword}\=.*\}\$\$/
    items = @action_txt.scan(reg)
    items.each do |item|
      result[keyword] = item.gsub("$${#{keyword}=","").gsub("}$$","").chomp("\"").gsub(/^\"/,"")
    end
  end
  result
end  

def get_transfer_properties(keyword_filter = DEFAULT_PARAMS_FILTER, strip_filter = false)
  result = {}
  STANDARD_PROPERTIES.each{|prop| result[prop.gsub("SS_","RPM_")] = @params[prop] }
  @params.each{|k,v| result[strip_filter ? k.gsub(keyword_filter,"") : k] = v if k.include?(keyword_filter) }
  result
end

def brpd_compatibility(props, payload_path, target_dir)
   props["VL_CONTENT_PATH"] = payload_path 
   props["VL_CONTENT_NAME"] = File.basename(payload_path) 
   props["VL_CHANNEL_ROOT"] = target_dir
end

def add_channel_properties(props, servers, os_plaform = "windows")
   s_props = servers.first[1]
   base_dir = s_props["CHANNEL_ROOT"] if s_props.has_key?("CHANNEL_ROOT")
   base_dir ||= s_props["base_dir"] if s_props.has_key?("base_dir")
   base_dir ||= get_platform_temp_dir(os_platform)
   props["VL_CHANNEL_ROOT"] = base_dir
   props["RPM_CHANNEL_ROOT"] = base_dir
end

def precision_timestamp
  Time.now.strftime("%Y%m%d%H%M%S%L")
end

def build_wrapper_script(os_platform, shebang, properties)
  msg = "Environment variables from BRPM"
  wrapper = "srun_wrapper_#{precision_timestamp}"
  cmd = shebang["cmd"]
  target = File.basename(@params["SS_script_file"])
  cmd = cmd.gsub("%%", target) if cmd.end_with?("%%")
  cmd = "#{cmd} #{target}" unless cmd.end_with?("%%")
  if os_platform =~ /win/
    properties["RPM_CHANNEL_ROOT"] = dos_path(properties["RPM_CHANNEL_ROOT"])
    properties["VL_CHANNEL_ROOT"] = properties["RPM_CHANNEL_ROOT"]
    wrapper = "#{wrapper}.bat"
    script = "echo #{msg} \r\n"
    properties.each{|k,v| script += "set #{k}=#{v}\r\n" }
    script +=  "echo Execute the file\r\n"
    script +=  "cd %RPM_CHANNEL_ROOT%\r\n"
    script +=  "#{cmd}\r\n"
  else
    wrapper = "#{wrapper}.sh"
    script = "echo #{msg} \n"
    properties.each{|k,v| script += "export #{k}=\"#{v}\"\n" }
    script +=  "echo Execute the file\n"
    script +=  "cd $RPM_CHANNEL_ROOT\n"
    script +=  "#{cmd}\n"    
  end
  fil = File.open(File.join(@output_dir, wrapper),"w+")
  fil.puts script
  fil.flush
  fil.close
  File.join(@output_dir, wrapper)
end

def read_shebang(os_platform)
  if os_platform =~ /win/
    result = {"ext" => ".sh", "cmd" => "/bin/sh -c", "shebang" => ""}
  else
    result = {"ext" => ".bat", "cmd" => "cmd /c", "shebang" => ""}
  end
  if @action_txt.include?("#![") # Custom shebang
    shebang = @action_txt.scan(/\#\!.*/).first
    result["shebang"] = shebang
    items = shebang.scan(/\#\!\[.*\]/)
    if items.size > 0
      result["ext"] = items[0].gsub("[.","").gsub("]","") 
      result["cmd"] = shebang.gsub(items[0],"").strip
    else
      result["cmd"] = shebang
    end      
  elsif @action_txt.include?("#!/") # Basic shebang
    result["shebang"] = "standard"
  else # no shebang
    result["shebang"] = "none"
  end
  result
end

# Copies all files (recursively) from source to destination on target hosts
#
# ==== Attributes
#
# * +target_hosts+ - blade hostnames to copy to
# * +src_path+ - NSH path to source files
# * +target_path+ - path to copy to (same for all target_hosts)
#
# ==== Returns
#
# * results of command
def nsh_ncp(target_hosts, src_path, target_path, options = {})
  #ncp -vr /c/dev/SmartRelease_2/lib -h bradford-96204e -d "/c/dev/BMC Software/file_store"
  max_time = get_option(options,"max_time", 3600)
  cmd = "#{@nsh_path}/bin/ncp -vrA #{src_path} -h #{target_hosts.join(" ")} -d \"#{target_path}\""
  cmd = @test_mode ? "echo \"#{cmd}\"" : cmd
  log cmd if @verbose
  result = execute_shell(cmd, max_time)
  display_result(result)
end

# Runs a script on a remote server via NSH
#
# ==== Attributes
#
# * +target_hosts+ - blade hostnames to copy to
# * +script_path+ - nsh path to the script
# * +target_path+ - path from which to execute the script on the remote host
# * +options+ - hash of options (raw_result = true, max_time in seconds to execute)
#
# ==== Returns
#
# * results of command per host
def nsh_script_exec(target_hosts, script_path, target_path, options = {})
  max_time = get_option(options,"max_time", 3600)
  script_dir = File.dirname(script_path)
  err_file = touch_file("#{script_dir}/nsh_errors_#{precision_timestamp}.txt")
  out_file = touch_file("#{script_dir}/nsh_out_#{precision_timestamp}.txt")
  cmd = "#{@nsh_path}/bin/scriptutil -d \"#{target_path}\" -h #{target_hosts.join(" ")} -H \"Results from: %h\" -s #{script_path} 2>#{err_file} | tee #{out_file}"
  result = execute_shell(cmd, max_time)
  result["stdout"] = "#{result["stdout"]}\n#{File.open(out_file).read}"
  result["stderr"] = "#{result["stderr"]}\n#{File.open(err_file).read}"
  display_result(result)
end

# Executes a command via shell in a timeout loop
#
# ==== Attributes
#
# * +platform_info+ - hash of plaform info e.g. {"transport" => "nsh", "platform" => "windows", "language" => "batch"}
# ==== Returns
#
# * command_run hash {stdout => <results>, stderr => any errors, pid => process id, status => exit_code}
def execute_shell(command, max_time = 3600)
  cmd_result = {"stdout" => "","stderr" => "", "pid" => "", "status" => "1"}
  cmd_result["stdout"] = "Running #{command}\n"
  output_dir = File.join(@output_dir,"#{precision_timestamp}")
  errfile = "#{output_dir}_stderr.txt"
  cmd_result["stdout"] += "Script Output:\n"
  begin
    orig_stderr = $stderr.clone
    $stderr.reopen File.open(errfile, 'a' )
    timer_status = Timeout.timeout(max_time) {
      cmd_result["stdout"] += `#{command}`
      status = $?
      cmd_result["pid"] = status.pid
      cmd_result["status"] = status.to_i
    }
    stderr = File.open(errfile).read
    cmd_result["stderr"] = stderr if stderr.length > 2
  rescue Exception => e
    $stderr.reopen orig_stderr
    cmd_result["stderr"] = "ERROR\n#{e.message}\n#{e.backtrace}"
  ensure
    $stderr.reopen orig_stderr
  end
  File.delete(errfile)
  cmd_result
end
  
# Pretty display of cmd_result object
#
# ==== Attributes
#
# * +cmd_result+ - hash of results e.g. {"stdout" => "results", "stderr" => "", "pid" => "10245"}
# ==== Returns
#
# * text output of result
def display_result(cmd_result)
  return "No results" if cmd_result.nil?
  result = ""
  result = "ExitCode: #{cmd_result["status"]} - " if cmd_result.has_key?("status")
  result += "Process: #{cmd_result["pid"]}\nSTDOUT:\n#{cmd_result["stdout"]}\n"
  result = "STDERR:\n #{cmd_result["stderr"]}\n#{result}" if cmd_result["stderr"].length > 2
  result
end

def get_option(options, key, default_value = "")
  result = options.has_key?(key) ? options[key] : default_value
  result = default_value if result.is_a?(String) && result == ""
  result 
end

def dos_path(nix_path)
  path = ""
  return nix_path if nix_path.include?(":\\")
  path_array = nix_path.split("/")
  if path_array[1].length == 1 # drive letter
    path = "#{path_array[1]}:\\"
    path += path_array[2..-1].join("\\")
  else
    path += path_array[1..-1].join("\\")
  end
  path
end

def nsh_path(src_path, server = nil)
  path = ""
  if src_path.include?(":\\")
    path_array = src_path.split("\\")
    path = "/#{path_array[0].gsub(":","/")}"
    path += path_array[1..-1].join("/")
  else
    path = src_path
  end
  path = "//server#{path}" unless server.nil?
  path.chomp("/")
end

def touch_file(file_path)
  fil = File.open(file_path,"w+")
  fil.close
  file_path
end

# Provides a logging style output
#
# ==== Attributes
#
# * +txt+ - the text to output
# * +level+ - the log level [info, warn, ERROR]
# * +output_file+ - an alternate output file to log to (default is step output)
def log(txt, level = "INFO", output_file = nil)
  puts log_message(txt, level)
end

# Provides a pretty box for titles
#
# ==== Attributes
#
# * +msg+ - the text to output
# * +mtype+ - box type to display sep: a separator line, title a box around the message
def message_box(msg, mtype = "sep")
  tot = 72
  msg = msg[0..64] if msg.length > 65
  ilen = tot - msg.length
  if mtype == "sep"
    start = "##{"-" * (ilen/2).to_i} #{msg} "
    res = "#{start}#{"-" * (tot- start.length + 1)}#"
  else
    res = "##{"-" * tot}#\n"
    start = "##{" " * (ilen/2).to_i} #{msg} "
    res += "#{start}#{" " * (tot- start.length + 1)}#\n"
    res += "##{"-" * tot}#\n"   
  end
  log(res)
end

# Generates a log formatted mesage
#
# ==== Attributes
#
# * +message+ - the path to the uploaded attachment (from params)
# * +log_type+ - type of entry (DEBUG/WARN, etc)
#
# ==== Returns
#
# * message with timestamp and log type
# 
def log_message(message, log_type = "INFO")
  stamp = "#{Time.now.strftime("%H:%M:%S")}|#{log_type}> "
  message = "" if message.nil?
  message = message.inspect unless message.is_a?(String)
  message.split("\n").map{|l| "#{stamp}#{l}"}.join("\n")
end

#---------------------- Variables --------------------------#
# get the body of the action
DEFAULT_PARAMS_FILTER = "ENV_"
STANDARD_PROPERTIES = ["SS_application", "SS_component", "SS_environment", "SS_component_version", "request_number"]
DEFAULT_TEMP_DIR = {"windows" => "/C/Windows/temp", "linux" => "/tmp" }
@action_txt = File.open(@params["SS_script_file"]).read
@output_dir = @params["SS_output_dir"]
@nsh_path = "/opt/bmc/bladelogic/NSH"
@nsh_path = NSH_PATH if defined?(NSH_PATH)
platforms = ["win","nix"]
max_time = (get_option(@params, "step_estimate", "60").to_i) * 60

#---------------------- Main Script ------------------------#
keyword_items = get_keyword_items
params_filter = keyword_items.has_key?("RPM_PARAMS_FILTER") ? keyword_items["RPM_PARAMS_FILTER"] : DEFAULT_PARAMS_FILTER
transfer_properties = get_transfer_properties(params_filter)

log "#----------- Executing Script on Remote Hosts -----------------#"
log "# Script: #{@params["SS_script_file"]}"

# Loop through the platforms
platforms = ["win","nix"].each do |os|
  servers = get_platform_servers(os)
  next if servers.size == 0
  log "# Targets: #{servers.keys.join(",")}"
  log "# Setting Properties:"
  add_channel_properties(transfer_properties,servers)
  transfer_properties.each{|k,v| log "\t#{k} => #{v}" }
  shebang = read_shebang(os)
  script_path = build_wrapper_script(os, shebang, transfer_properties)
  log "# Wrapper: #{script_path}"
  target_path = nsh_path(transfer_properties["RPM_CHANNEL_ROOT"])
  log "# Copying script to target:"
  result = nsh_ncp(servers.keys, @params["SS_output_file"], target_path, {"max_time" => max_time})
  log result
  log "# Executing script on target:"
  result = nsh_script_exec(servers.keys, script_path, target_path, {"max_time" => max_time})
  log result
end  
