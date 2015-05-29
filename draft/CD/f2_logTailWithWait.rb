#---------------------- f2_logTailWithWait -----------------------#
# Description: Tails log on a remote server with an initial wait
# Executes on ALL Servers selected for step
#  copies all the standard properties and prefixed properties(ENV_) to environment variables
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
#
#---------------------- Arguments --------------------------#
###
# Log Location:
#   name: path to log
#   type: in-text
#   position: A1:F1
# Wait Time:
#   name: Time in seconds to wait (default = 60 seconds)
#   type: in-text
#   position: A2:C2
# Tail Size:
#   name: Amount of log to tail (default = 100 lines)
#   type: in-text
#   position: A3:C3
# Find Text:
#   name: Text to find in log (optional)
#   type: in-text
#   position: A4:F4
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = "yes"
#require 'C:/BMC/persist/automation_libs/brpm_framework.rb'
require '/opt/bmc/persist/automation_lib/brpm_framework.rb'

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
log_location = @p.required("Log Location")
wait_time = @p.get("Wait Time", "60")
tail_size = @p.get("Tail Size", "100")
find_text = @p.get("Find Text")

#---------------------- Main Body --------------------------#
# Note RPM_CHANNEL_ROOT will be set in the run script routine

@rpm.message_box "Tailing Log: #{File.basename(log_location)}", "title"
@rpm.log "LogFile: #{log_location}"
@rpm.log "Sleeping for: #{wait_time} seconds"
servers = @rpm.get_server_list
if log_location.start_with?("//")
  nsh_path = log_location
else
  nsh_path = File.join("//#{servers.keys.first}",log_location)
end
cmd = "tail -#{tail_size} #{nsh_path}"
@rpm.message_box "Running: #{cmd}"
interval = (wait_time.to_i / 4).to_i
result = ""
4.times do
  result += @nsh.nsh_command(cmd)
  if find_text != "" && result.include?(find_text)
    @rpm.log result
    break
  end
  sleep interval
end

unless find_text == ""
  if result.include?(find_text)
    @rpm.log "Success - found: #{find_text}"
  else
    raise "ERROR - could not find #{find_text} in log"
  end
end


