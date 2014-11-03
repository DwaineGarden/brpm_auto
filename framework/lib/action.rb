# Base class for working with actions - e.g. shell and other languages - supports BRPD actions
class Action < BrpmAutomation
  require 'popen4'
  require 'timeout'
  require 'erb'

  # Initializes an instance of the class
  #
  # ==== Attributes
  #
  # * +params_obj+ - pass the params object from the main script (@p)
  # * +options+ - hash of options includes:
  #
  def initialize(params_obj, options = {})
    @standard_properties = ["SS_application", "SS_component", "SS_environment", "SS_component_version", "request_number"]
    @p = params_obj
    super @p
    lib_path = @p.get("SS_script_support_path")
    @action_platforms = {"default" => {"transport" => "nsh", "platform" => "linux", "language" => "bash", "comment_char" => "#", "env_char" => "", "lb" => "\n", "ext" => "sh"}}
    @action_platforms.merge!(ACTION_PLATFORMS) if defined?(ACTION_PLATFORMS)
    @automation_category = get_option(options, "automation_category", @p.get("SS_automation_category", "shell"))
    @output_dir = get_option(options, "output_dir", @p.get("SS_output_dir"))
    action_platform(options)
    @nsh_path = get_option(options,"nsh_path", NSH_PATH)
    @debug = get_option(options, "debug", false)
    @nsh = NSH.new(@nsh_path)
    set_transfer_properties(options)
    timeout = get_option(options, "timeout", @p.get("step_estimate", "60"))
    @timeout = timeout.to_i * 60
  end

  # Translates the automation_category into platform information
  #
  # ==== Attributes
  #
  # * +category+ - automation category
  # ==== Returns
  #
  # * hash of plaform info e.g. {"transport" => "nsh", "platform" => "windows", "language" => "batch"}
  def action_platform(options = {})
    @platform = get_option(options, "platform")
    @platform_info = get_option(options, "action_platform", nil)
    @platform = @platform_info["platform"] unless @platform_info.nil?
    @platform = @automation_category if @platform == ""
    found_platform = {}
    @action_platforms.each{|k,v| 
      if @platform =~ /#{k}/
        @platform_info = v
        @platform = k
        break
      end
       }
    @platform_info = @action_platforms["default"] if @platform_info.nil?
    found_platform
  end
  
  # Overrides the build-in platform information
  #
  # ==== Attributes
  #
  # * +automation_category+ - automation_category to associate with platform_info
  # * +platform_info+ - hash of plaform info e.g. {"transport" => "nsh", "platform" => "windows", "language" => "batch"}
  # ==== Returns
  #
  # * 
  def set_platform_info(platform, platform_info)
    @platform = platform
    @platform_info = platform_info
  end
  
  # Sets the properties to env up as environment variables
  #
  # ==== Attributes
  #
  # * +options+ - hash of options - looking for transfer_properties or property_filter (prefix in params), retain_property_prefix leaves the prefix on
  # ==== Returns
  #
  # * Sets the @transfer_properties instance var
  def set_transfer_properties(options)
    @transfer_properties = get_option(options, "transfer_properties", {})
    prop_filter = get_option(options, "property_filter", "ARG_")
    retain_prefix = get_option(options, "retain_property_prefix", false)
    @p.local_params.each{|k,v| @transfer_properties[(retain_prefix ? k : k.gsub(prop_filter,""))] = v if k.start_with?(prop_filter) }
    @p.params.each{|k,v| @transfer_properties[(retain_prefix ? k : k.gsub(prop_filter,""))] = v if k.start_with?(prop_filter) }
    @transfer_properties
  end
    
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
    wrapper_path = wrapper_script(wrapper_script, action_path, target_path, servers) if wrapper_script
    pre_process_action(action_path, payload_path)
    script_path = wrapper_script.nil? ? action_path : wrapper_path
    cmd = "#{@nsh_path}/bin/scriptutil -d \"#{target_path}\" -h #{servers.join(" ")} -s #{script_path} -H \"Results from: %h\""
    result = execute_shell(cmd, max_time)
    message_box "Script Results"
    log display_result(result)
    res = remove_temp_files(action_path, target_path, servers) if wrapper_script && !@debug
    result
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

  # Executes a script directly via NSH
  #  use this if you have an nsh script to run from the localhost
  # ==== Attributes
  #
  # * +action+ - may be a path to action or text of action
  # * +max_time+ - maximum time to run (sec) - default = 3600
  # ==== Returns
  #
  # * command_run hash {stdout => <results>, stderr => any errors, pid => process id, status => exit_code}
  def run_nsh_local!(action, max_time = 3600)
    if action =~ /\/|\\/
      action_path = action
    else
      action_path = create_temp_action(action)
    end
    result = @nsh.nsh(action_path, true)
    result
  end

  # Detects need for a wrapper script - creates it and copies to targets
  # looks for "WRAPPER: " in the first 10 lines, use it like a shebang ex:
  # # WIN_WRAPPER: C:\\apps\perl %%
  # this line will be plucked out of the script and a new batch script created with it
  # upin execution, both the batch script and the main script will be copied to the targets
  # then the batch script will be run which will call the main script from the %% keyword
  # filename will be automatically substituted in.
  # ==== Attributes
  #
  # * +action_path+ - path to script to transport
  # * +target_path+ - path on target to copy to
  # * +servers+ - array of servers to copy to
  # ==== Returns
  #
  # * path to wrapper script
  
  def wrapper_script(wrapper_script, action_path, target_path, servers)
    lb = line_break
    env = @platform_info["environment_set"]
    cmt = @platform_info["comment_char"]
    script_name = File.basename(action_path)
    if windows?
      win_path = @nsh.dos_path(target_path)
      ext = "bat"
      script_path = "#{win_path}\\#{script_name}"
    else
      ext = "sh"
      script_path = "#{target_path}/#{script_name}"
    end
    log "Executing via wrapper script:"
    wrapper_script.chomp!("\r") 
    wrapper_script.gsub!("%%", script_path) if wrapper_script.include?("%%")
    wrapper_script += " #{script_path}" unless wrapper_script.include?("%%")
    wrapper += lb
    new_path = create_temp_action(wrapper_script, "wrapper_#{precision_timestamp}.#{ext}")
    log "\t Target:    #{new_path}"
    log "\t Wrapper:   #{wrapper_script}"
    result = @nsh.ncp(servers, action_path, target_path)
    log "\t Copy Results:    #{result}"
    new_path
  end

  # Copies payload to targets and then returns path on target
  #
  # ==== Attributes
  #
  # * +payload_path+ - path to script to transport
  # * +target_path+ - path on target to copy to
  # * +servers+ - array of servers to copy to
  # ==== Returns
  #
  # * path to payload on target
  def transport_payload(payload_path, target_path, servers)
    file_name = File.basename(payload_path)
    if @platform_info["platform"] == "windows"
      win_path = @nsh.dos_path(target_path)
      file_path = "#{win_path}\\#{file_name}"
    else
      file_path = "#{target_path}/#{file_name}"
    end
    log "Transporting payload:"
    log "\t Target:    #{file_path}"
    result = @nsh.ncp(servers, payload_path, target_path)
    log "\t Copy Results:    #{result}"
    file_path
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

  # Add header and environment variables and processes ERB in an action_file
  # 
  # ==== Attributes
  #
  # * +action_path+ - path to action on the file system
  # ==== Returns
  #
  # modified action text
  #
  def pre_process_action(action_path, payload_path = nil)
    lb = line_break
    env = @platform_info["environment_set"]
    cmt = @platform_info["comment_char"]
    language = @platform_info["language"]
    shebang = ""
    content = File.open(action_path).read
    content = ERB.new(content).result(binding)
    items = content.scan(/^\s*\#\!.*/)
    shebang = items[0] if items.size > 0
    if payload_path
      @transfer_properties["RPM_PAYLOAD"] = payload_path
    end
    env_header = "#{cmt} Environment vars to define#{lb}"
    @standard_properties.each{|prop| @transfer_properties[prop] = @p.get(prop) }
    @transfer_properties.each do |key,val|
      env_header += "#{env}#{key}=#{val}#{lb}" if language == "batch"
      env_header += "#{env}#{key}=\"#{val}\"#{lb}" unless language == "batch"
    end
    file_content = "#{shebang}#{lb}#{env_header}#{lb}#{content}"
    fil = File.open(action_path,"w+")
    fil.puts file_content
    fil.flush
    fil.close
    file_content
  end
  
  # Sets BRPD Compatibility properties
  # 
  # ==== Returns
  #
  # hash
  #
  def brpd_compatibility(payload_path, target_dir)
     @transfer_properties["VL_CONTENT_PATH"] = payload_path 
     @transfer_properties["VL_CONTENT_NAME"] = File.basename(payload_path) 
     @transfer_properties["VL_CHANNEL_ROOT"] = target_dir

  end

  # Returns a temp name for the action on the target
  # 
  # ==== Returns
  #
  # action name
  #
  def temp_action_name
    file_name = "action_#{@platform_info["language"]}_#{precision_timestamp}.#{@platform_info["ext"]}"
  end
  
  private
  
  def create_temp_action(action, file_name)
    file_path = File.join(@output_dir, file_name)
    fil = File.open(file_path,"w+")
    fil.puts(action)
    fil.flush
    fil.close
    File.chmod(0755,file_path)
    file_path
  end
  
  def windows?
    @platform_info["platform"].downcase =~ /windows/
  end
  
  def linux?
    !windows?
  end
  
  def line_break
    windows? ? "\r\n" : "\n"
  end
  
  def remove_temp_files(file_path, target_path, servers)
    return "" if @debug
    result = ["Removing files"]
    script_name = File.basename(file_path)
    servers.each do |server|
      cmd = "rm //#{server}/#{target_path}/#{script_name}"
      result << @nsh.nsh_command(cmd)
    end
    result.join("\n")
  end

end

