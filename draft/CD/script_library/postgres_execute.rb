#---------------------- f2_postgresExecuteWin -----------------------#
# Description: Executes sql command on target_servers (windows)
# Executes on ALL Servers selected for step
#  copies all the standard properties and prefixed properties(ENV_) to environment variables
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
#
#---------------------- Arguments --------------------------#
###
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
def postgres_execute_win(db_user, db_password, db_name, sql_command)
  cur_server = @p.get_server_list.keys.first
  raise "No server selected" if cur_server.length < 3
  channel_root = @p.get_server_property(cur_server, "CHANNEL_ROOT")
  channel_root = "C:\\temp" if channel_root == ""
  @rpm.message_box "SQL Command"
  @rpm.log "#\tServer: #{cur_server} at #{channel_root}"
  @rpm.log "#\tSQL: #{sql_command}"
  db_arg = db_name == "postgres" ? "" : "-d #{db_name} " 
  sql_file = @transport.make_temp_file(sql_command, "windows", {"ext" => ".sql"})
  @transport.copy_file(sql_file, @nsh.nsh_path(channel_root,cur_server))
  cmd = "echo off\r\nset PGPASSWORD=#{db_password}\r\n\"#{@postgres_path}\\bin\\psql.exe\" -U #{db_user} #{db_arg}-a -f #{File.basename(sql_file)}"
  script_file = @transport.make_temp_file(cmd, "windows")
  result = @transport.execute_script(script_file, {"transfer_properties" => {} })  
end  

#---------------------- Variables --------------------------#
os = "windows"
cur_server = @p.get_server_list.keys.first
staging_info = @p.get("instance_#{@p.SS_component}")
channel_root = @p.get_server_property("CHANNEL_ROOT", cur_server)
@postgres_path = @p.required("postgres_path")
postgres_admin_username = @p.required("postgres_admin_user")
postgres_admin_password = @p.required("postgres_admin_password")
postgres_username = @p.required("postgres_user")
postgres_password = @p.required("postgres_password")
install_database = @p.required("install_database") #"rpm_install_db"
customer_database = @p.required("customer_database") #"rpm_customer_db"
customer_dump_file = @p.required("customer_dump_file") #"C:\\BMC\\templatedb.sql"
transfer_properties = {}

#---------------------- Main Body --------------------------#
# Install BRPM after jenkins download on Windows server
#  Expecting these variable to be set
#  silent_install_path
#  brpm_path
#  RPM_artifact_name_<component>

@rpm.message_box "Executing Postgres commands", "title"
#  Drop Db and re-add
sql = "drop database #{install_database};\n create database #{install_database} with owner=#{postgres_username}"
result = postgres_execute_win(postgres_admin_username,postgres_admin_password,"postgres", sql)
@rpm.log result

#  Drop and re-add Customer Db
sql = "drop database #{customer_database};\n create database #{customer_database} with owner=#{postgres_username}"
result = postgres_execute_win(postgres_admin_username,postgres_admin_password,"postgres", sql)
@rpm.log result

#  Import db dump
cmd = "echo off\r\nset PGPASSWORD=#{postgres_password}\r\n \"#{@postgres_path}\\bin\\psql.exe\" -U #{postgres_username} #{customer_database} < #{customer_dump_file}"
@rpm.log "SQL: #{cmd}"
script_file = @transport.make_temp_file(cmd, "windows")
result = @transport.execute_script(script_file, {"transfer_properties" => {} })
len = result.length
@rpm.log result if len < 32000
@rpm.log "#{result[0..32000]}\n[truncated]\n#{result[(len-1000)..len]}" if len > 32000

