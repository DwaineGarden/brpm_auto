# Helper Routines for Capistrano
require 'capistrano'
require 'capistrano/cli'
require 'timeout'

class TransportSSH < BrpmAutomation
  
  # Initialize the class
  #
  # ==== Attributes
  #
  # * +servers+ - array of servers to use
  # * +params+ - the params hash
  # * +options+ - hash of options to use, user, password, sudo (yes/no), timeout (minutes)
  #
  def initialize(servers, params, options = {})
    @user = get_option(options, "user", nil)
    @password = get_option(options, "password", nil)
    @servers = servers
    @sudo = get_option(options, "sudo", nil)
    @debug = get_option(options, "debug", false)
    super(params)
    @cap = Capistrano::Configuration.new
    @cap.logger.level = Capistrano::Logger::TRACE
    maxtime = get_option(options, "timeout", 60)
    @maxtime = maxtime.to_i * 60
  end
    
  # Resets the security credentials
  #
  # ==== Attributes
  #
  # * +options+ - hash of options [user,password,sudo, debug, servers]
  # 
  def set_credential(options = {})
    @user = get_option(options, "user", @user)
    @password = get_option(options, "password", @password)
    @servers = get_option(options, "servers", @servers) 
    @sudo = get_option(options, "sudo", @sudo)
    @debug = get_option(options, "debug", @debug)
  end

  # Execute a command on remote targets
  #
  # ==== Attributes
  #
  # * +command+ - command to execute
  # * +options+ - hash of options includes servers to override class servers
  #
  # ==== Returns
  #
  # command_run hash {stdout => <results>, stderr => any errors, pid => process id, status => exit_code}
  def execute_command(command, options = {})
    @servers = get_option(options, "servers", @servers)
    execute_cap "command", {"command" => command}
  end

  # Copy files to remote targets
  #
  # ==== Attributes
  #
  # * +source_files+ - array of files to copy
  # * +target_path+ - path on target hosts to copy to
  # * +options+ - hash of options includes servers to override class servers
  #
  # ==== Returns
  #
  # command_run hash {stdout => <results>, stderr => any errors, pid => process id, status => exit_code}
  def copy_files(source_files, target_path, options = {})
    @servers = get_option(options, "servers", @servers)
    source_files = [source_files] if source_files.is_a?(String)
    execute_cap "upload", {"source_files" => source_files, "target_path" => target_path}
  end

  # Download files to staging from remote targets
  #
  # ==== Attributes
  #
  # * +source_files+ - array of file paths to copy
  # * +staging_path+ - path on local server to copy to
  # * +options+ - hash of options includes servers to override class servers
  #
  # ==== Returns
  #
  # command_run hash {stdout => <results>, stderr => any errors, pid => process id, status => exit_code}
  def download_files(source_files, target_path, options = {})
    @servers = get_option(options, "servers", @servers)
    source_files = [source_files] if source_files.is_a?(String)
    execute_cap "download", {"source_files" => source_files, "target_path" => target_path}
  end

  # Copies script to remote targets and executes it (bin/bash)
  #
  # ==== Attributes
  #
  # * +script_path+ - path to script file on local host
  # * +target_path+ - path on target servers to copy to
  # * +options+ - hash of options includes servers to override class servers
  #
  # ==== Returns
  #
  # command_run hash {stdout => <results>, stderr => any errors, pid => process id, status => exit_code}
  def script_exec(script_path, target_path, options = {})
    @servers = get_option(options, "servers", @servers)
    copy_files [script_path], target_path
    cmd = "/bin/bash #{File.join(target_path, File.basename(script_path))}"
    result = execute_command(cmd)
    cmd = "rm -f #{File.join(target_path, File.basename(script_path))}"
    cleanunp_result = execute_command(cmd) unless @debug
    result
  end

  # Resets the servers for ssh execution
  #
  # ==== Attributes
  #
  # * +servers+ - array of servers
  #
  def set_servers(servers)
    @servers = servers
  end
  
  private
  
  # Executes the capistrano command in a timeout loop integrating stderr and stdout
  #
  # ==== Attributes
  #
  # * +cap_method+ - can be command, upload, download
  # * +options+ - hash of options specific to the command type
  #  
  # ==== Returns
  #
  # * command_run hash {stdout => <results>, stderr => any errors, pid => process id, status => exit_code}
  def execute_cap(cap_method, options = {}, max_time = @max_time)
    cmd_result = {"stdout" => "","stderr" => "", "pid" => "", "status" => 1}
    show_errors = true #@params.has_key?("ignore_exit_codes") ? !(@params["ignore_exit_codes"] == 'yes') : false
    @cap.set :user, @user unless @user.nil?
    @cap.set :password, @password unless @password.nil?
    @cap.role :all do
      @servers
    end
    cmd_result["stdout"] = "Capistrano Execution\n"
    output_dir = File.join("/tmp","#{"brady333"}") #FIXME
    outfile = "#{output_dir}_stderr.txt"
    cmd_result["stdout"] += "Script Output:\n"
    begin
      orig_stderr = $stderr.clone
      $stderr.reopen File.open(outfile, 'a' )
      fil = File.open(outfile, 'a' )
      timer_status = Timeout.timeout(max_time) {
        rescue_cap_errors(show_errors) do
          if cap_method == "command"
            command = options["command"]
            cmd_result["stdout"] += "Command: #{command}"
            use_sudo = @sudo.nil? ? "no" : @sudo
            @cap.run "#{use_sudo == 'yes' ? "sudo " : '' } #{command}", :pty => (use_sudo == 'yes') do |ch, str, data|
              if str == :out
                fil.puts data
                fil.flush
              elsif str == :err
                cmd_result["stderr"] += data if data.length > 4
              end
            end
          elsif cap_method == "upload"
            source_files = options["source_files"]
            target_path = options["target_path"]
            cmd_result["stdout"] += "Upload: #{source_files.join(",")} |To: #{target_path}"
            source_files.each do |file_path|
              ans = split_nsh_path(file_path)
              f_path = ans[1]
              cmd_result["stdout"] += "File: #{f_path}\n"
              @cap.upload f_path, target_path, :via => :scp
            end
          elsif cap_method == "download"
            source_files = options["source_files"]
            target_path = options["target_path"]
            cmd_result["stdout"] += "Download: #{source_files.join(",")} |To: #{target_path}"
            source_files.each do |file_path|
              ans = split_nsh_path(file_path)
              f_path = ans[1]
              cmd_result["stdout"] += "File: #{f_path}\n"
              target_file = File.join(target_path, File.basename(f_path))
              @cap.download f_path, target_file, :via => :scp
            end
          end
        end
      }
      fil.close
      fil1 = File.open(outfile)
      output = fil1.read
      fil1.close
      cmd_result["stdout"] = output if output.length > 2
      cmd_result["status"] = 0
    rescue Exception => e
      $stderr.reopen orig_stderr
      cmd_result["stderr"] += "ERROR\n#{e.message}\n#{e.backtrace}"
    ensure
      $stderr.reopen orig_stderr
    end
    File.delete(outfile)
    cmd_result
  end

  def rescue_cap_errors(show_errors, &block)
    begin
      yield
    rescue RuntimeError => failure
      if show_errors
        log "SSH-Capistrano_Error: #{failure.message}\n#{failure.backtrace}"
        log "#{EXIT_CODE_FAILURE}" 
      end
    end
  end

end
