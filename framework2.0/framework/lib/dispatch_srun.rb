# dispatch_srun.rb
#  Module for action dispatch with nsh protocol

require 'erb'
require 'digest/md5'

DEFAULT_PARAMS_FILTER = "ENV_"
STANDARD_PROPERTIES = ["SS_application", "SS_component", "SS_environment", "SS_component_version", "SS_request_number"]
OS_PLATFORMS = {
  "win" => {"name" => "Windows", "tmp_dir" => "/C/Windows/temp"},
  "nix" => {"name" => "Unix", "tmp_dir" => "/tmp"},
  "nux" => {"name" => "Linux", "tmp_dir" => "/tmp"}}


class SrunDispatcher < NSHTransport
  # Initialize the class
  #
  # ==== Attributes
  #
  # * +nsh_path+ - path to NSH dir on files system (must contain br directory too)
  # * +options+ - hash of options to use, send "output_file" to point to the logging file
  # * +test_mode+ - true/false to simulate commands instead of running them
  #
  def initialize(nsh_path, params, options = {})
    @nsh_path = nsh_path
    @verbose = get_option(options, "verbose", false)
    @params = params
    super(@nsh_path, params)
    @run_key = get_option(options,"timestamp",Time.now.strftime("%Y%m%d%H%M%S"))
    @output_dir = get_param("SS_output_dir")
    insure_proxy
  end

  # Builds a hash of properties to transfer to target
  # 
  # ==== Attributes
  #
  # * +keyword_filter+ - filter for params (param selected if filter included in key)
  # * +strip_filter+ - removes filter text from resulting key
  # ==== Returns
  #
  # hash of properties to transfer
  #
  def get_transfer_properties(keyword_filter = DEFAULT_PARAMS_FILTER, strip_filter = false)
    result = {}
    STANDARD_PROPERTIES.each{|prop| result[prop.gsub("SS_","RPM_")] = params[prop] }
    params.each{|k,v| result[strip_filter ? k.gsub(keyword_filter,"") : k] = get_param(k) if k.include?(keyword_filter) }
    result
  end

  # Add BRPD-like params to transfer_properties
  # 
  # ==== Attributes
  #
  # * +props+ - the existing transfer properties hash
  # * +payload_path+ - the path for any previously delivered content
  # * +target_dir+ - the delivery directory on the target
  # ==== Returns
  #
  # nothing - modifies passed property hash
  #
  def brpd_compatibility(props, payload_path = nil)
     props["VL_CONTENT_PATH"] = payload_path if payload_path
     props["VL_CONTENT_NAME"] = File.basename(payload_path)  if payload_path
     props["VL_CHANNEL_ROOT"] = props["RPM_CHANNEL_ROOT"]
  end

  # Add server properties to transfer properties
  # 
  # ==== Attributes
  #
  # * +props+ - the existing transfer properties hash
  # * +servers+ - hash of server properties
  # * +os_platform+ - os platform
  # ==== Returns
  #
  # nothing - modifies passed property hash
  #
  def add_channel_properties(props, servers, os_platform = "win")
     s_props = servers.first[1]
     base_dir = s_props["CHANNEL_ROOT"] if s_props.has_key?("CHANNEL_ROOT")
     base_dir ||= s_props["base_dir"] if s_props.has_key?("base_dir")
     base_dir ||= OS_PLATFORMS[os_platform]["tmp_dir"]
     props["RPM_CHANNEL_ROOT"] = base_dir
  end


  # Builds the wrapper script for the target
  # sets environment variables and call to run target script
  # follows platform directives or shebang information
  #
  # ==== Attributes
  #
  # * +os_platform+ - os platform
  # * +shebang+ - hash of processed shebang
  # * +properties+ - hash of properties to become environment variables
  # ==== Returns
  #
  # path to wrapper script
  #
  def build_wrapper_script(os_platform, shebang, properties)
    msg = "Environment variables from BRPM"
    wrapper = "srun_wrapper_#{precision_timestamp}"
    cmd = shebang["cmd"]
    target = File.basename(get_param("SS_script_file"))
    cmd = cmd.gsub("%%", target) if shebang["cmd"].end_with?("%%")
    cmd = "#{cmd} #{target}" unless shebang["cmd"].end_with?("%%")
    if os_platform =~ /win/
      properties["RPM_CHANNEL_ROOT"] = dos_path(properties["RPM_CHANNEL_ROOT"])
      properties["VL_CHANNEL_ROOT"] = properties["RPM_CHANNEL_ROOT"]
      wrapper = "#{wrapper}.bat"
      script = "@echo off\r\necho |hostname > junk.txt\r\nset /p HOST=<junk.txt\r\nrm junk.txt\r\n"
      script += "echo ============== HOSTNAME: %HOST% ==============\r\n"
      script += "echo #{msg} \r\n"
      properties.each{|k,v| script += "set #{k}=#{v}\r\n" }
      script +=  "echo Execute the file\r\n"
      script +=  "cd %RPM_CHANNEL_ROOT%\r\n"
      script +=  "#{cmd}\r\n"
      script +=  "timeout /T 500\r\necho y | del #{target}\r\n"
    else
      wrapper = "#{wrapper}.sh"
      script = "echo \"============== HOSTNAME: `hostname` ==============\"\n"
      script += "echo #{msg} \n"
      properties.each{|k,v| script += "export #{k}=\"#{v}\"\n" }
      script +=  "echo Execute the file\n"
      script +=  "cd $RPM_CHANNEL_ROOT\n"
      script +=  "#{cmd}\n"    
      script +=  "sleep 2\nrm -f #{target}"    
    end
    fil = File.open(File.join(@output_dir, wrapper),"w+")
    fil.puts script
    fil.flush
    fil.close
    File.join(@output_dir, wrapper)
  end

  # Removes carriage returns for unix compatibility
  # Opens passed script path, modifies and saves file
  # ==== Attributes
  #
  # * +os_platform+ - os platform
  # * +script_file+ - path to script to modify
  # * +contents+ - optional - if passed will replace the content in script_file
  # ==== Returns
  #
  # path to modified script
  #
  def clean_line_breaks(os_platform, script_file, contents = nil)
    return if os_platform =~ /win/
    contents = File.open(script_file).read if contents.nil?
    fil = File.open(script_file,"w+")
    fil.puts contents.gsub("\r", "")
    fil.flush
    fil.close
    script_file
  end

  # Wrapper to run a shell action
  # Opens passed script path, or executes passed text
  # ==== Attributes
  #
  # * +params+ - the params hash
  # * +nsh_path+ - path to nsh
  # ==== Returns
  #
  # action output
  #
  def run_action(script_file, options = {})
    # get the body of the action
    content = script_file if script_file.include?("\n")
    content = File.open(script_file).read
    action_txt = ERB.new(content).result(binding)
    keyword_items = get_keyword_items(content)
    params_filter = keyword_items.has_key?("RPM_PARAMS_FILTER") ? keyword_items["RPM_PARAMS_FILTER"] : DEFAULT_PARAMS_FILTER
    transfer_properties = get_transfer_properties(params_filter, strip_prefix = true)
    log "#----------- Executing Script on Remote Hosts -----------------#"
    log "# Script: #{@params["SS_script_file"]}"

    # Loop through the platforms
    OS_PLATFORMS.each do |os, details|
      servers = get_platform_servers(os)
      message_box "OS Platform: #{details["name"]}"
      log "No servers selected for: #{details["name"]}" if servers.size == 0
      next if servers.size == 0
      log "# #{details["name"]} - Targets: #{servers.inspect}"
      log "# Setting Properties:"
      add_channel_properties(transfer_properties, servers, os)
      brpd_compatibility(transfer_properties)
      transfer_properties.each{|k,v| @rpm.log "\t#{k} => #{v}" }
      shebang = read_shebang(os, action_txt)
      log "Shebang: #{shebang.inspect}"
      script_path = build_wrapper_script(os, shebang, transfer_properties)
      log "# Wrapper: #{script_path}"
      target_path = nsh_path(transfer_properties["RPM_CHANNEL_ROOT"])
      log "# Copying script to target: "
      clean_line_breaks(os, @params["SS_script_file"], action_txt)
      result = "# Script at: #{@params["SS_script_file"]}"
      result = ncp(servers.keys, @params["SS_script_file"], target_path)
      log result
      log "# Executing script on target:"
      result = script_exec(servers.keys, script_path, target_path)
      log result
    end
  end
  
  def stage_files(file_list, version)
    staging_path = staging_dir(version, true)
    message_box "Copying Files to Staging over NSH"
    log "\t StagingPath: #{staging_path}"
    file_list.each do |file_path|
      log "\t #{file_path}"
      result = ncp(nil, file_path, staging_path)
      log "\tCopy Result: #{result}"
    end
    cmd = "cd #{staging_path} && zip -r package_#{version}.zip *"
    result = execute_shell(cmd)
    instance_path = File.join(staging_path, "package_#{version}.zip")
    md5 = Digest::MD5.file(instance_path).hexdigest
    {"instance_path" => instance_path, "md5" => md5}
  end
  
  def get_attachment_nsh_path(attachment_local_path, brpm_hostname)
    if attachment_local_path[1] == ":"
      attachment_local_path[1] = attachment_local_path[0]
      attachment_local_path[0] = '/'
    end
    attachment_local_path = attachment_local_path.gsub(/\\/, "/")
    "//#{brpm_hostname}#{attachment_local_path}"
  end
 
  def split_nsh_path(path)
    result = ["",path]
    result[0] = path.split("/")[2] if path.start_with?("//")
    result[1] = "/#{path.split("/")[3..-1].join("/")}" if path.start_with?("//")  
    result
  end

end
