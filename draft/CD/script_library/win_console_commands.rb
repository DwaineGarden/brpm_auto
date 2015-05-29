#---------------------- f2_commandExecute -----------------------#
# Description: Executes a command on target_servers
# Executes on ALL Servers selected for step
#  copies all the standard properties and prefixed properties(ENV_) to environment variables
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
#
#---------------------- Arguments --------------------------#
###
# Command:
#   name: command to execute
#   type: in-text
#   position: A1:F1
# Target Path:
#   name: Path on target to run the command from
#   type: in-text
#   position: A2:F2
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = "yes"
#require 'C:/BMC/persist/automation_libs/brpm_framework.rb'
require '/opt/bmc/persist/automation_lib/brpm_framework.rb'

#---------------------- Methods ----------------------------#
def postgres_execute_win(db_user, db_password, sql_file)
  cmd = "set PGPASSWORD=#{db_password}\r\n\"#{@postgres_path}\\bin\\psql\" -U #{db_user} -d #{db_name} -a -f \"#{sql_file}\""
end  

def postgres_dump_win(db_name, db_user, db_password, dump_file)
  cmd = "set PGPASSWORD=#{db_password}\r\n\"#{@postgres_path}\\bin\\pg_dump\" -U #{db_user} -d #{db_name} > \"#{dump_file}\""
end  

def uninstall_brpm(silent_file_path)
  cmd = "cd \"#{@brpm_path} & UninstallBMCBRLM\"\r\nuninstall.cmd -i silent -DOPTIONS_FILE=#{silent_file_path}"
end

def install_brpm(silent_file_path)
  cmd = "cd \"#{temp_path} & UninstallBMCBRLM\"\r\nuninstall.cmd -i silent -DOPTIONS_FILE=#{silent_file_path}"
end

curl = "C:\\bmc\\curl.exe"
url = "http://vw-aus-rem-dv11.bmc.com:8080/job/Trunk_BRPM_INSTALLERS/356/artifact/BRPM_Windows_201505220925.zip"
options = {"method" => "get", "username" => username, "password" => password}
def curl_download_win(curl_cmd, download_url, options = {})
  download_file = File.basename(download_url)
  method = get_option(options, "method", "get").upcase
  auth = ""
  auth = " --user #{options["username"]}:#{options["password"]}" unless get_option(options, "username") == ""
  cmd = "cd #{channel_root}\r\n"
  cmd = "#{curl_cmd} -X #{method}#{auth} #{download_url} > #{download_file}"
end

def postgres_table_size_win()
  cmd = "SELECT relname as \"Table\", pg_size_pretty(pg_total_relation_size(relid)) As \"Size\", "
  cmd += "pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) as \"External Size\" "
  cmd += "FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;"
end

#---------------------- Variables --------------------------#
command = @p.required("Command")
target_path = @p.get("Target Path")
transfer_properties = {}
@postgres_path = "C:\\Program Files\\PostgreSQL\\9.4"
@brpm_path = "C:\\Program Files\\BMC Software\\RLM"

#---------------------- Main Body --------------------------#
# Note RPM_CHANNEL_ROOT will be set in the run script routine

@rpm.message_box "Executing command", "title"
@rpm.log "Command: #{command}"
script_file = @transport.make_temp_file(command)
result = @transport.execute_script(script_file, {"transfer_properties" => transfer_properties})
#@rpm.log "SRUN Result: #{result.inspect}"
exit_status = "Success"
result.split("\n").each{|line| exit_status = line if line.start_with?("EXIT_CODE:") }
pack_response("output_status", exit_status)
@p.assign_local_param("script_#{@p.SS_component}", script_file)
@p.save_local_params



