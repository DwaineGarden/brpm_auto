require 'popen4'


class BrpmAutomation
  
  def get_option(options, key, default_value = "")
    result = options.has_key?(key) ? options[key] : default_value
    result = default_value if result.is_a?(String) && result == ""
    result 
  end

  def required_item(options, key)
    result = get_option(options, key)
    raise ArgumentError, "Missing required argument: #{key}" if result == ""
    result
  end
  
  def write_to(txt)
  	puts txt
  end
  
  def run_shell(cmd)
  	  cmd_result = {"stdout" => "","stderr" => "", "pid" => ""}
      begin
	      status = IO.popen4(cmd) do |pid, stdin, stdout, stderr|
	        stdin.close
	        [
	          Thread.new(stdout) {|stdout_io|
	            stdout_io.each_line do |l|
	              cmd_result["stdout"] += l
	            end
	            stdout_io.close
	          },
	
	          Thread.new(stderr) {|stderr_io|
	            stderr_io.each_line do |l|
	             cmd_result["stderr"] += l
	            end
	          }
	        ].each( &:join )
	        cmd_result["pid"] = pid
	      end
  	  rescue Exception => e
  		  cmd_result["stderr"] += "#{e.message}\n#{e.backtrace}"
  	  end
      cmd_result
  end
  
  def shell_result(cmd_result)
  	cmd_result["stderr"].length > 2 ? "#{cmd_result["stdout"]}\nSTDERR: #{cmd_result["stderr"]}" : cmd_result["stdout"]
  end
  


end

class NSH < BrpmAutomation
  
  attr_writer :test_mode
  
  def initialize(nsh_path, options = {}, test_mode = false)
    @nsh_path = nsh_path
    @test_mode = test_mode
    @opts = options
    @run_key = get_option(options,"timestamp",Time.now.strftime("%Y%m%d%H%M%S"))
    insure_proxy
  end
  
  def insure_proxy
    return true if get_option(@opts, "bl_profile") == ""
    res = get_cred
    puts res
  end
  
  def cred_errors?(status)
  	errors = ["EXPIRED","cache is empty"]
  	errors.each do |err|
  		return true if status.include?(err)
  	end
  	return false
  end
  
  def get_cred
    bl_cred_path = File.join(@nsh_path,"bin","blcred")
    cred_status = `#{bl_cred_path} cred -list`
    puts "Current Status:\n#{cred_status}" if @test_mode
    if (cred_errors?(cred_status))
      # get cred
      cmd = "#{bl_cred_path} cred -acquire -profile #{get_option(@opts,"bl_profile")} -username #{get_option(@opts,"bl_username")} -password #{get_option(@opts,"bl_password")}"
      res = run_shell(cmd)
      puts display_result(res) if @test_mode
      result = "Acquiring new credential"
    else
	  result = "Current credential is valid"
    end
    result
  end
  
  def create_temp_script(body, options)
    script_type = get_option(options,"script_type", "nsh")
    base_path = get_option(options, "temp_path")
    tmp_file = "#{script_type}_temp_#{@run_key}.#{script_type}"
    full_path = "#{base_path}/#{tmp_file}"
    fil = File.open(full_path,"w+")
    fil.puts body
    fil.flush
    fil.close
    full_path
  end

  def nsh(script_path)
    cmd = "#{@nsh_path}/bin/nsh #{script_path}"
    cmd = @test_mode ? "echo \"#{cmd}\"" : cmd 
    result = run_shell(cmd)
    display_result(result)
  end

  def nsh_command(command)
    path = create_temp_script("echo Running #{command}\n#{command}\n",{"temp_path" => "/tmp"})
    nsh(path)
  end

  def ncp(target_hosts, src_path, target_path)
    #ncp -vr /c/dev/SmartRelease_2/lib -h bradford-96204e -d "/c/dev/BMC Software/file_store"
    cmd = "#{@nsh_path}/bin/ncp -vrA #{src_path} -h #{target_hosts.join(" ")} -d \"#{target_path}\""
    cmd = @test_mode ? "echo \"#{cmd}\"" : cmd 
    result = run_shell(cmd)
    display_result(result)
  end
  
  def nexec(target_hosts, target_path, source_script=nil)
    # if source_script exists, transport it to the hosts
    src_file = ""
    src_file = "/" + File.basename(source_script) if source_script
    destination_script = "#{target_path}/tmp_#{@run_key}#{src_file}"
    result = "Nexec Proc"
    result += ncp(target_hosts, source_script,destination_script)
    cmd = "#{@nsh_path}/bin/nexec -i #{target_hosts.first} cmd /c \"#{dos_path(destination_script)}\""
    cmd = @test_mode ? "echo \"#{cmd}\"" : cmd 
    result = run_shell(cmd)
    display_result(result)
  end

  def script_exec(target_hosts, script_path, target_dir)
    cmd = "#{@nsh_path}/bin/scriptutil -d \"#{target_dir}\" -h \"#{target_hosts.join(" ")}\" -s #{script_path}"
    result = `#{cmd}`
    result
  end
  
  def dos_path(nix_path)
    path = ""
    path_array = nix_path.split("/")
    if path_array[1].length == 1 # drive letter
      path = "#{path_array[1]}:\\" 
      path += path_array[2..-1].join("\\")
    else
      path += path_array[1..-1].join("\\")
    end
    path
  end
end

#-----------------------------------#
#  MAIN SCRIPT
def set_env_vars(fil)
	fil.puts("export NSHDIR=/app/bmc/BladeLogic/8.2/NSH")
	fil.puts("export LD_LIBRARY_PATH=/app/bmc/BladeLogic/8.2/NSH/lib:$LD_LIBRARY_PATH")
	fil.puts("export PATH=/app/bmc/BladeLogic/8.2/NSH/bin:$PATH")
	fil.puts("export HOTDISH=tuna_casserole")
end
nsh_path = "/app/bmc/BladeLogic/8.2/NSH"

options = {"bl_profile" => "DEVBLAPP", "bl_username" => "RPMDev", "bl_password" => "testtest1"}

#nsh_cmd = ARGV[0]
nsh = NSH.new(nsh_path,options)

source_path = "/app/ge/config/nextgen"
host = "nycdlvaeng001.ny.rbcds.com"
ls_cmd = "ls -R //#{host}#{source_path}"
staging_dir = "/home/scratchNT/BMC-BladeLogic/BRPM/config_project/staging/live"
copy_cmd = "cp -r //#{host}#{source_path} #{staging_dir}"
#result = nsh.nsh_command(ls_cmd)
result = nsh.nsh_command(copy_cmd)
#result = nsh.ncp([host],source_path,staging_dir)
puts "#-----NSH Results ----#"
puts result
 
