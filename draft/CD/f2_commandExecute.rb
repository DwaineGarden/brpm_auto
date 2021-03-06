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
# Success:
#   name: String to indicate success (optional)
#   type: in-text
#   position: A3:F3
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

#---------------------- Variables --------------------------#
os = "windows"
command = @p.required("Command")
target_path = @p.get("Target Path")
transfer_properties = {}
success = @p.get("Success")

#---------------------- Main Body --------------------------#
# Note RPM_CHANNEL_ROOT will be set in the run script routine

@rpm.message_box "Executing command", "title"
@rpm.log "Command: #{command}"
command = "cd #{target_path}\n#{command}" if target_path.length > 2
script_file = @transport.make_temp_file(command, os)
result = @transport.execute_script(script_file, {"transfer_properties" => transfer_properties})
#@rpm.log "SRUN Result: #{result.inspect}"
exit_status = "Success"
result.split("\n").each{|line| exit_status = line if line.start_with?("EXIT_CODE:") }
if success != ""
  if result.include?(success)
    exit_status = "Success - found term: #{success}"
  else
    exit_status = "Command_Failed: term not found: #{success}"
  end
end
@rpm.log exit_status
raise "ERROR: success term not found" if exit_status.include?("Command_Failed")

pack_response("output_status", exit_status)
@p.assign_local_param("script_#{@p.SS_component}", script_file)
@p.save_local_params



