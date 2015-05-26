###
# Server Profile:
#   name: Server profile
#   type: in-text
#   position: A1:C1
###

#---------------------- Declarations ------------------------------#
require 'yaml'
#FRAMEWORK_DIR = @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib") unless defined?(FRAMEWORK_DIR)
@script_name_handle = "nsh_browse_token"
body = File.open(File.join(FRAMEWORK_DIR,"lib","resource_framework.rb")).read
result = eval(body)

#=== General Integration Server: BMA Sandbox ===#
# [integration_id=10100]
SS_integration_dns = "lwtd014.hhscie.txaccess.net"
SS_integration_username = "bmaadmin"
SS_integration_password = "-private-"
SS_integration_details = "BMA_HOME: /bmc/bma/BLAppRelease-8.5.0.a557498.gtk.linux.x86_64
BMA_LICENSE: /bmc/bma/BLAppRelease-8.5.0.a557498.gtk.linux.x86_64/TexasHealth5997ELO_ML.lic
BMA_WORKING: /bmc/bma_working
BMA_PLATFORM: Linux"
SS_integration_password_enc = "__SS__Cj00V2F0UldZaDFtWQ=="
#=== End ===#

#---------------------- Main Script ------------------------------#
class NSH
  
  attr_writer :test_mode
  
  def initialize(nsh_path, options = {}, test_mode = false)
    @nsh_path = nsh_path
    @test_mode = test_mode
    @opts = options
    @run_key = get_option(options,"timestamp",Time.now.strftime("%Y%m%d%H%M%S"))
    insure_proxy
  end
  
  def get_option(options, key, default_value = "")
    result = options.has_key?(key) ? options[key] : default_value
    result = default_value if result.is_a?(String) && result == ""
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
    
  def display_result(cmd_result)
    cmd_result["stderr"].length > 2 ? "#{cmd_result["stdout"]}\nSTDERR: #{cmd_result["stderr"]}" : cmd_result["stdout"]
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

  def nsh_dir(nsh_path)
    res = nsh_command("ls #{nsh_path}")
    res.split("\n").reject{|l| l.start_with?("Running ")}
  end
end

def is_dir(nsh_path)
  res = @nsh.nsh_command("test -d #{nsh_path}; echo $?")
  res.split("\n")[2] == "0"
end

def path_data(data_ptr, dir_path)
  paths = @nsh.nsh_dir(dir_path).map{|k| [k,dir_path] }
  paths.each do |path|
    log_it( path.inspect)
	next if path[0] =~ /^\d\d\d\d\d\d\d\d.*/
    is_folder = is_dir(File.join(path[1],path[0]))
    data_ptr << { :title => path[0], :key => "#{path[0]}|#{path[1]}", :isFolder => is_folder, :hasChild => is_folder}
  end
  data_ptr
end  

def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  server_profile = script_params["Server Profile"]
  log_it "ScriptParams: #{script_params.inspect}"
  nsh_path = defined?(BAA_BASE_PATH) ? "#{BAA_BASE_PATH}/NSH" : "/opt/bmc/bladelogic/NSH"
  @nsh = NSH.new(nsh_path, script_params)
  integration_details = YAML.load(SS_integration_details)
  bma_snapshots_path = "#{integration_details["BMA_WORKING"]}/snapshots"

  begin
    if parent_id.blank?
      # root folder
      log_it "Setting root"
      dir = File.join("//#{SS_integration_dns}", bma_snapshots_path)
      data = []
	    path_data(data, dir)
	    log_it(data)
      return data
    else
      # clicked_item|/opt/bmc/stuff
      log_it "Drilling in: #{parent_id}"
      dir = File.join(parent_id.split("|")[1],parent_id.split("|")[0])
      dir = "/#{dir}" if parent_id.split("|")[1] == "//"
      data = []
	    path_data(data, dir)
	    log_it(data)
      data
    end
  rescue Exception => e
    log_it "#{e.message}\n#{e.backtrace}"
  end
end

def import_script_parameters
  { "render_as" => "Tree" }
end

