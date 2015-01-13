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
  #
  # ==== Returns
  #
  # * cred result message
  def get_cred
    bl_cred_path = safe_cmd("blcred")
    cred_status = `#{bl_cred_path} cred -list`
    puts "Current Status:\n#{cred_status}" if @test_mode
    if (cred_errors?(cred_status))
      # get cred
      cmd = "#{bl_cred_path} cred -acquire -profile #{get_option(@opts,"bl_profile")} -username #{get_option(@opts,"bl_username")} -password #{get_option(@opts,"bl_password")}"
      res = execute_shell(cmd)
      puts display_result(res) if @test_mode
      result = "Acquiring new credential"
    else
      result = "Current credential is valid"
    end
    result
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
    path = create_temp_script("echo Running #{command}\n#{command}\n")
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
    paths = src_path.map{|pth| pth.include?(" ") ? "\"#{pth}\"" : pth }
    path_arg = paths.join(" ")
    cmd = "#{nsh_cmd("ncp")} -vrA #{path_arg} -h #{target_hosts.join(" ")} -d \"#{target_path}\"" unless target_hosts.nil?
    #cmd = "#{nsh_cmd("cp")} -vr #{path_arg.gsub("localhost","@")} #{target_path}" if target_hosts.nil?
    if target_hosts.nil? # Local copy
      FileUtils.cp_r path_arg.gsub("//localhost",""), target_path, :verbose => true
      res = "cp #{path_arg.gsub("//localhost","")} #{target_path}"
    else
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
    cmd = "#{nsh_cmd("scriptutil")} -d \"#{target_path}\" -h #{target_hosts.join(" ")} -H \"Results from: %h\" -s #{script_path}"
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
    script_file = "nsh_script_#{Time.now.strftime("%Y%m%d%H%M%S")}.sh"
    full_path = File.join(@params["SS_output_dir"],script_file)
    fil = File.open(full_path,"w+")
    #fil.write script_body.gsub("\r", "")
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
      path = source_path
    end
    path = "//server#{path}" unless server.nil?
    path.chomp("/")
  end
    
  # Builds an NSH compatible path for an uploaded file to BRPM
  # 
  # ==== Attributes
  #
  # * +attachment_local_path+ - path to attachment from params 
  # * +brpm_hostname+ - name of brpm host (as accessible from NSH)
  # ==== Returns
  #
  # nsh path
  #
  def get_attachment_nsh_path(attachment_local_path, brpm_hostname)
    if attachment_local_path[1] == ":"
      attachment_local_path[1] = attachment_local_path[0]
      attachment_local_path[0] = '/'
    end
    attachment_local_path = attachment_local_path.gsub(/\\/, "/")
    "//#{brpm_hostname}#{attachment_local_path}"
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
    return {"instance_path" => "ERROR - no files in staging area", "md5" => ""} if Dir.entries(staging_path).size < 3
    FileUtils.cd(staging_path, :verbose => true)
    cmd = "#{nsh_cmd("zip")} -r #{package_name} *"
    result = execute_shell(cmd)
    md5 = Digest::MD5.file(instance_path).hexdigest
    {"instance_path" => instance_path, "md5" => md5}
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
