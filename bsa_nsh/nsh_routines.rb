###
# database:
#   description: database backup to check
###
# Inits to run separately
@params = params = {
	"SS_output_dir" => "/c/dev/tmp"
	}
def write_to(txt)
	puts txt
end
def run_command(params, command, arguments, b_quiet = false)
  command = command.is_a?(Array) ? command.flatten.first : command
  data_returned = ""
  write_to("========================\n Running: #{command} \n========================") unless b_quiet
  data_returned = `#{command} #{arguments} 2>&1`
  #data_returned = CGI::escapeHTML(data_returned)
  write_to data_returned  unless b_quiet
  write_to("=============  Results End ==============")  unless b_quiet
  return data_returned
end

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
	write_to(res)
end

#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
argument_one = params["argument_one"]
success = "app" # pick a term that will mean success in the output
params["direct_execute"] = true
@test_mode = false
@run_key =Time.now.to_i
target_servers = ["bradford-96204e"]
files_to_copy = "/c/dev/SmartRelease_2/lib"
destination_path = "/c/dev/BMC Software/file_store"

#---------------------- Methods ----------------------------#
# Assign local variables to properties and script arguments
def create_temp_script(body, script_type="nsh")
	tmp_file = "#{script_type}_temp_#{@run_key}.#{script_type}"
	full_path = "#{@params["SS_ouptut_dir"]}/#{tmp_file}"
	fil = File.open(full_path,"w+")
	fil.puts body
	fil.close
	full_path
end

def nsh_execute(script_path)
	cmd = "nsh #{script_path}"
	cmd = @test_mode ? "echo \"#{cmd}\"" : cmd 
	result = run_command(@params, cmd, '')
end	

def ncp_copy(target_hosts, src_path, target_path)
	#ncp -vr /c/dev/SmartRelease_2/lib -h bradford-96204e -d "/c/dev/BMC Software/file_store"
	cmd = "ncp -vrA #{src_path} -h #{target_hosts.join(" ")} -d \"#{target_path}\""
	cmd = @test_mode ? "echo \"#{cmd}\"" : cmd 
	result = run_command(@params, cmd, "")
end

def nexec_execute(target_hosts, target_path, source_script=nil)
	# if source_script exists, transport it to the hosts
	src_file = ""
	src_file = "/" + File.basename(source_script) if source_script
	destination_script = "#{target_path}/tmp_#{@run_key}#{src_file}"
	result = "Nexec Proc"
	result += ncp_copy(target_hosts, source_script,destination_script)
	cmd = "nexec -i #{target_hosts.first} cmd /c \"#{dos_path(destination_script)}\""
	cmd = @test_mode ? "echo \"#{cmd}\"" : cmd 
	result = run_command(@params, cmd, "")
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

#---------------------- Main Body --------------------------#
# Do your work here

# Set test Mode operation:

  #--- set local variables

  #--- Build NSH Commands
  nsh_cmd =<<-END
  cd //#{target_servers.first}
  ls "#{destination_path}/lib"
  END

  nexec_cmd =<<-END
  dir #{dos_path(destination_path)}\lib
  set
  END
  
  #--- Collect the files to the Repo ---#
 result = ncp_copy(target_servers, files_to_copy, destination_path)
 message_box "Checking Results"
  #--- Execute in NSH context
  file_result = create_temp_script(nsh_cmd)
  nsh_execute(file_result)

message_box "Checking Results in DOS"
file_path = create_temp_script(nexec_cmd,"bat")
result += nexec_execute(target_servers, destination_path, file_path)

  params["success"] = "fixtures"
  
  result += params["success"] if @test_mode

  #--- Apply success or failure criteria
if result.index(params["success"]).nil?
  write_to "Command_Failed - term not found: [#{params["success"]}]\n"
else
  write_to "Success - found term: #{params["success"]}\n"
end
