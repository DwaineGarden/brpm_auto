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


#---------------------- Methods ----------------------------#

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

def add_channel_properties(props, servers, os_platform = "win")
   s_props = servers.first[1]
   base_dir = s_props["CHANNEL_ROOT"] if s_props.has_key?("CHANNEL_ROOT")
   base_dir ||= s_props["base_dir"] if s_props.has_key?("base_dir")
   base_dir ||= OS_PLATFORMS[os_platform]["tmp_dir"]
   props["VL_CHANNEL_ROOT"] = base_dir
   props["RPM_CHANNEL_ROOT"] = base_dir
end


def build_wrapper_script(os_platform, shebang, properties)
  msg = "Environment variables from BRPM"
  wrapper = "srun_wrapper_#{@rpm.precision_timestamp}"
  cmd = shebang["cmd"]
  target = File.basename(@params["SS_script_file"])
  cmd = cmd.gsub("%%", target) if shebang["cmd"].end_with?("%%")
  cmd = "#{cmd} #{target}" unless shebang["cmd"].end_with?("%%")
  if os_platform =~ /win/
    properties["RPM_CHANNEL_ROOT"] = @rpm.dos_path(properties["RPM_CHANNEL_ROOT"])
    properties["VL_CHANNEL_ROOT"] = properties["RPM_CHANNEL_ROOT"]
    wrapper = "#{wrapper}.bat"
    script = "@echo off\r\necho |hostname > junk.txt\r\nset /p HOST=<junk.txt\r\nrm junk.txt\r\n"
    script += "echo ============== HOSTNAME: %HOST% ==============\r\n"
    script += "echo #{msg} \r\n"
    properties.each{|k,v| script += "set #{k}=#{v}\r\n" }
    script +=  "echo Execute the file\r\n"
    script +=  "cd %RPM_CHANNEL_ROOT%\r\n"
    script +=  "#{cmd}\r\n"
  else
    wrapper = "#{wrapper}.sh"
    script = "echo \"============== HOSTNAME: `hostname` ==============\"\n"
    script += "echo #{msg} \n"
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

def fake_transport(source_file, target_dir)
  @rpm.log "Transporting to: #{File.join(target_dir, File.basename(source_file))}"
  FileUtils.cp(source_file, target_dir, :verbose => true)
end

def clean_line_breaks(script_file, os_platform)
  return if os_platform =~ /win/
  contents = File.open(script_file).read
  fil = File.open(script_file,"w+")
  fil.puts contents.gsub("\r", "")
  fil.flush
  fil.close
end

#---------------------- Variables --------------------------#
# get the body of the action
DEFAULT_PARAMS_FILTER = "ENV_"
STANDARD_PROPERTIES = ["SS_application", "SS_component", "SS_environment", "SS_component_version", "SS_request_number"]
OS_PLATFORMS = {
  "win" => {"name" => "Windows", "tmp_dir" => "/C/Windows/temp"},
  "nix" => {"name" => "Unix", "tmp_dir" => "/tmp"},
  "nux" => {"name" => "Linux", "tmp_dir" => "/tmp"}}
SS_output_file = @params["SS_output_file"]
@nsh_path = "#{defined?(NSH_PATH) ? NSH_PATH : "/opt/bmc/blade8.5"}/NSH"
@action_txt = File.open(@params["SS_script_file"]).read
@output_dir = @params["SS_output_dir"]
max_time = (@rpm.get_option(@params, "step_estimate", "60").to_i) * 60
@nsh = NSHTransport.new(@nsh_path)

#---------------------- Main Script ------------------------#
keyword_items = get_keyword_items
params_filter = keyword_items.has_key?("RPM_PARAMS_FILTER") ? keyword_items["RPM_PARAMS_FILTER"] : DEFAULT_PARAMS_FILTER
transfer_properties = get_transfer_properties(params_filter, strip_prefix = true)

@rpm.log "#----------- Executing Script on Remote Hosts -----------------#"
@rpm.log "# Script: #{@params["SS_script_file"]}"

# Loop through the platforms
OS_PLATFORMS.each do |os, details|
  servers = get_platform_servers(os)
  @rpm.message_box "OS Platform: #{details["name"]}"
  @rpm.log "No servers selected for: #{details["name"]}" if servers.size == 0
  next if servers.size == 0
  @rpm.log "# #{details["name"]} - Targets: #{servers.inspect}"
  @rpm.log "# Setting Properties:"
  add_channel_properties(transfer_properties, servers, os)
  transfer_properties.each{|k,v| @rpm.log "\t#{k} => #{v}" }
  shebang = read_shebang(os, @action_txt)
  script_path = build_wrapper_script(os, shebang, transfer_properties)
  @rpm.log "# Wrapper: #{script_path}"
  target_path = @rpm.nsh_path(transfer_properties["RPM_CHANNEL_ROOT"])
  @rpm.log "# Copying script to target: "
  clean_line_breaks(@params["SS_script_file"], os)
  result = "# (simulate) Script at: #{@params["SS_script_file"]}"
  fake_transport(@params["SS_script_file"], target_path)
  #result = nsh.ncp(servers.keys, @params["SS_script_file"], target_path, {"max_time" => max_time})
  @rpm.log result
  @rpm.log "# Executing script on target:"
  fake_transport(script_path, target_path)
  result = run_command(@params, "/bin/bash #{File.join(target_path, File.basename(script_path))}")
  #result = nsh.script_exec(servers.keys, script_path, target_path, {"max_time" => max_time})
end  
