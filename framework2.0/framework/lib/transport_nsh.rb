# Wrapper class for NSH interactions
class TransportNSH < BrpmAutomation

  attr_writer :test_mode

  # Initialize the class
  #
  # ==== Attributes
  #
  # * +nsh_path+ - path to NSH dir on files system (must contain br directory too)
  # * +options+ - hash of options to use, send "output_file" to point to the logging file
  # * +test_mode+ - true/false to simulate commands instead of running them
  #
  def initialize(nsh_path, params, options = {}, test_mode = false)
    @nsh_path = nsh_path
    @test_mode = test_mode
    @verbose = get_option(options, "verbose", false)
    super(params) unless params.nil?
    @opts = options
    @run_key = get_option(options,"timestamp",Time.now.strftime("%Y%m%d%H%M%S"))
    outf = get_option(options,"output_file", SS_output_file)
    @output_dir = File.dirname(outf)
    insure_proxy
  end

  # Verifies that proxy cred is set
  #
  # ==== Returns
  #
  # * blcred cred -acquire output
  def insure_proxy
    return true if get_option(@opts, "bl_profile") == ""
    res = get_cred
    puts res
  end

  # Displays any errors from a cred status
  #
  # ==== Attributes
  #
  # * +status+ - output from cred command
  #
  # ==== Returns
  #
  # * true/false
  def cred_errors?(status)
    errors = ["EXPIRED","cache is empty"]
    errors.each do |err|
        return true if status.include?(err)
    end
    return false
  end

  # Performs a cred -acquire
  # ==== Attributes
  #
  # * +opts+ - pass the credential options to relogin [bl_profile, bl_username, bl_password]
  #
  # ==== Returns
  #
  # * cred result message
  def get_cred(opts = {})
    @opts = opts if opts.has_key?("bl_profile")
    return "No profile provided - assume direct agent access" unless @opts.has_key?("bl_profile")
    @test_mode = get_option(opts, "test_mode", @test_mode)
    bl_cred_path = nsh_cmd("blcred")
    cred_status = `#{bl_cred_path} cred -list`
    log "Current Status:\n#{cred_status}" if @test_mode
    if (cred_errors?(cred_status))
      # get cred
      cmd = "#{bl_cred_path} cred -acquire -profile #{get_option(@opts,"bl_profile")} -username #{get_option(@opts,"bl_username")} -password #{get_option(@opts,"bl_password")}"
      res = execute_shell(cmd)
      log display_result(res) if @test_mode
      result = "Acquiring new credential"
    else
      result = "Current credential is valid"
    end
    result
  end

  # An alias for get_cred
  def set_credential(opts = {})
    get_cred(opts)
  end
  
  # Runs an nsh script
  #
  # ==== Attributes
  #
  # * +script_path+ - path (local to rpm server) to script file
  #
  # ==== Returns
  #
  # * results of script
  def nsh(script_path, raw_result = false)
    cmd = "#{nsh_cmd("nsh")} #{script_path}"
    cmd = @test_mode ? "echo \"#{cmd}\"" : cmd
    result = execute_shell(cmd)
    return result if raw_result
    display_result(result)
  end

  # Runs a simple one-line command in NSH
  #
  # ==== Attributes
  #
  # * +command+ - command to run
  #
  # ==== Returns
  #
  # * results of command
  def nsh_command(command, raw_result = false)
    path = create_temp_script("echo Running #{command.gsub("\n"," - ")}\n#{command}\n")
    result = nsh(path, raw_result)
    File.delete path unless @test_mode
    result
  end

  # Copies all files (recursively) from source to destination on target hosts
  #
  # ==== Attributes
  #
  # * +target_hosts+ - blade hostnames to copy to
  # * +src_path+ - NSH path to source files (may be an array)
  # * +target_path+ - path to copy to (same for all target_hosts)
  #
  # ==== Returns
  #
  # * results of command
  def ncp(target_hosts, src_path, target_path)
    #ncp -vr /c/dev/SmartRelease_2/lib -h bradford-96204e -d "/c/dev/BMC Software/file_store"
    src_path = [src_path] if src_path.is_a?(String)
    if target_hosts.nil?
      res = split_nsh_path(src_path[0])
      target_hosts = [res[0]] unless res[0] == ""
      target_hosts = nil if res[0].include?("localhost") || res[0].include?("127.0.0.1")
      src_path[0] = res[1] unless res[0] == ""
    end
    paths = src_path.map{|pth| pth.include?(" ") ? "\"#{pth}\"" : pth }
    path_arg = paths.join(" ")
    cmd = "#{nsh_cmd("ncp")} -vrA #{path_arg} -h #{target_hosts.join(" ")} -d \"#{target_path}\"" unless target_hosts.nil?
    #cmd = "#{nsh_cmd("cp")} -vr #{path_arg.gsub("localhost","@")} #{target_path}" if target_hosts.nil?
    if target_hosts.nil? && path_arg.start_with?("/")  # Local copy
      path = path_arg.gsub("//localhost","").gsub("//127.0.0.1","")
      FileUtils.cp_r path, target_path, :verbose => true
      res = "cp #{path} #{target_path}"
    else
      staging_path = nsh_path(target_path)
      cmd = @test_mode ? "echo \"#{cmd}\"" : cmd
      log cmd if @verbose
      result = execute_shell(cmd)
      res = display_result(result)
    end
    res
  end

  # Runs a command via nsh on a windows target
  #
  # ==== Attributes
  #
  # * +target_hosts+ - blade hostnames to copy to
  # * +target_path+ - path to copy to (same for all target_hosts)
  # * +command+ - command to run
  #
  # ==== Returns
  #
  # * results of command per host
  def nexec_win(target_hosts, target_path, command)
    # if source_script exists, transport it to the hosts
    result = "Running: #{command}\n"
    target_hosts.each do |host|
      cmd = "#{nsh_cmd("nexec")} #{host} cmd /c \"cd #{target_path}; #{command}\""
      cmd = @test_mode ? "echo \"#{cmd}\"" : cmd
      result += "Host: #{host}\n"
      res = execute_shell(cmd)
      result += display_result(res)
    end
    result
  end

  # Runs a script on a remote server via NSH
  #
  # ==== Attributes
  #
  # * +target_hosts+ - blade hostnames to copy to
  # * +script_path+ - nsh path to the script
  # * +target_path+ - path from which to execute the script on the remote host
  # * +options+ - hash of options (raw_result = true)
  #
  # ==== Returns
  #
  # * results of command per host
  def script_exec(target_hosts, script_path, target_path, options = {})
    raw_result = get_option(options,"raw_result", false)
    script_dir = File.dirname(script_path)
    err_file = touch_file("#{script_dir}/nsh_errors_#{Time.now.strftime("%Y%m%d%H%M%S%L")}.txt")
    script_path = "\"#{script_path}\"" if script_path.include?(" ")
    cmd = "#{nsh_cmd("scriptutil")} -d \"#{nsh_path(target_path)}\" -h #{target_hosts.join(" ")} -s #{script_path}"
    cmd = cmd + " 2>#{err_file}" unless Windows
    result = execute_shell(cmd)
    result["stderr"] = "#{result["stderr"]}\n#{File.open(err_file).read}"
    result = display_result(result) unless raw_result
    result
  end

  # Executes a text variable as a script on remote targets
  #
  # ==== Attributes
  #
  # * +target_hosts+ - array of target hosts
  # * +script_body+ - body of script
  # * +target_path+ - path on targets to store/execute script
  #
  # ==== Returns
  #
  # * output of script
  #
  def script_execute_body(target_hosts, script_body, target_path, options = {})
    ext = get_option(options,"platform", "linux").downcase == "linux" ? ".sh" : ".bat"
    script_file = "nsh_script_#{Time.now.strftime("%Y%m%d%H%M%S")}#{ext}"
    full_path = File.join(@params["SS_output_dir"],script_file)
    fil = File.open(full_path,"w+")
    fil.write script_body.gsub("\r", "")
    fil.flush
    fil.close
    result = script_exec(target_hosts, full_path, target_path, options)
  end

  # Runs a simple ls command in NSH
  #
  # ==== Attributes
  #
  # * +nsh_path+ - path to list files
  #
  # ==== Returns
  #
  # * array of path contents
  def ls(nsh_path)
    res = nsh_command("ls #{nsh_path}")
    res.split("\n").reject{|l| l.start_with?("Running ")}
  end

  # Provides a host status for the passed targets
  #
  # ==== Attributes
  #
  # * +target_hosts+ - array of hosts
  #
  # ==== Returns
  #
  # * hash of agentinfo on remote hosts
  def status(target_hosts)
    result = {}
    target_hosts.each do |host|
      res = nsh_command("agentinfo #{host}")
      result[host] = res
    end
    result
  end

  # Returns the nsh path from a dos path
  #
  # ==== Attributes
  #
  # * +source_path+ - path in nsh
  # * +server+ - optional, adds a server in nsh format
  #
  # ==== Returns
  #
  # * nsh compatible path
  #
  def nsh_path(source_path, server = nil)
    path = ""
    if source_path.include?(":\\")
      path_array = source_path.split("\\")
      path = "/#{path_array[0].gsub(":","/")}"
      path += path_array[1..-1].join("/")
    else
      path = source_path.gsub(":","")
      path = "/#{path}" unless path.start_with?("/")
    end
    path.gsub!(" ","\\ ")
    path = "//#{server}#{path}" unless server.nil?
    path.chomp("/")
  end

  # Zip files using NSH
  # 
  # ==== Attributes
  #
  # * +staging_path+ - path to files
  # * +package_name+ - name of zip file to create
  # ==== Returns
  #
  # hash of instance_path and md5 - {"instance_path" => "", "md5" => ""}
  def package_staged_artifacts(staging_path, package_name)
    instance_path = File.join(staging_path, package_name)
    staging_artifacts = Dir.entries(staging_path).reject{|k| [".",".."].include?(k) }
    return {"instance_path" => "ERROR - no files in staging area", "md5" => ""} if staging_artifacts.size < 1
    FileUtils.cd(staging_path, :verbose => true)
    log "Creating zip archive"
    zip_cmd = nsh_cmd("zip")
    zip_cmd = "zip" if !File.exist?(zip_cmd)
    cmd = "#{zip_cmd} -r #{package_name} *"
    result = execute_shell(cmd)
    log display_result(result)
    md5 = Digest::MD5.file(instance_path).hexdigest
    {"instance_path" => instance_path, "md5" => md5, "manifest" => staging_artifacts }
  end

  # Copies a single file from source to destination via nsh paths
  #
  # ==== Attributes
  #
  # * +src_path+ - NSH path to source files
  # * +target_path+ - NSH path to copy to 
  #
  # ==== Returns
  #
  # * results of command
  def cp(src_path, target_path)
    cmd = "#{nsh_cmd("cp")} -f #{src_path} #{target_path}"
    cmd = @test_mode ? "echo \"#{cmd}\"" : cmd
    log cmd if @verbose
    result = execute_shell(cmd)
    res = display_result(result)
    res
  end

  private

  def create_temp_script(body, options = {})
    script_type = get_option(options,"script_type", "nsh")
    base_path = get_option(options, "temp_path", platform_temp)
    tmp_file = "#{script_type}_temp_#{precision_timestamp}.#{script_type}"
    full_path = "#{base_path}/#{tmp_file}"
    fil = File.open(full_path,"w+")
    fil.puts body
    fil.flush
    fil.close
    full_path
  end
  
  def nsh_cmd(cmd)
    res = File.join(@nsh_path, "bin", cmd)
    res = "\"#{res}\"" if res.include?(" ")
    res
  end
  
  def platform_temp
    res = "/tmp"
    res = "C:/Windows/temp" if Windows
    res
  end
end
