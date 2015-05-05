@rpm.message_box "Running nsh command", "title"
# BSA Server 8.5.1
# clm-aus-003365/9840 BLAdmin
@rpm.log @rpm.display_result(result)
remote_server = "clm-aus-003365.bmc.com"
command = "echo Running comand from BRPM\r\n"
command = "dir C:\\Program Files\\BMC Software\\RLM\\lib\\jruby\\bin\r\n"
result = @nsh.script_execute_body([remote_server], command, "C:\\temp")
@rpm.log result