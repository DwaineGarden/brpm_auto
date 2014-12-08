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
    bl_cred_path = File.join(@nsh_path,"bin","blcred")
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
    cmd = "#{@nsh_path}/bin/nsh #{script_path}"
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
    path = create_temp_script("echo Running #{command}\n#{command}\n",{"temp_path" => "/tmp"})
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
    src_path = src_path.join(" ") if src_path.is_a?(Array)
    cmd = "#{@nsh_path}/bin/ncp -vrA #{src_path} -h #{target_hosts.join(" ")} -d \"#{target_path}\"" unless target_hosts.nil?
    cmd = "#{@nsh_path}/bin/cp -vr #{src_path} #{target_path}" if target_hosts.nil?
    cmd = @test_mode ? "echo \"#{cmd}\"" : cmd
    log cmd if @verbose
    result = execute_shell(cmd)
    display_result(result)
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
      cmd = "#{@nsh_path}/bin/nexec #{host} cmd /c \"cd #{target_path}; #{command}\""
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
    cmd = "#{@nsh_path}/bin/scriptutil -d \"#{target_path}\" -h #{target_hosts.join(" ")} -H \"Results from: %h\" -s #{script_path} 2>#{err_file}"
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
    full_path = "#{File.dirname(SS_output_file)}/#{script_file}"
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

  private

  def create_temp_script(body, options)
    script_type = get_option(options,"script_type", "nsh")
    base_path = get_option(options, "temp_path")
    tmp_file = "#{script_type}_temp_#{precision_timestamp}.#{script_type}"
    full_path = "#{base_path}/#{tmp_file}"
    fil = File.open(full_path,"w+")
    fil.puts body
    fil.flush
    fil.close
    full_path
  end

end