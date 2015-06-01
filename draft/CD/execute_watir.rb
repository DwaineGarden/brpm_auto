#---------------------- f2_executeWatir -----------------------#
# Description: Launches a WAtir script on a remote machine via nsh
# Executes on ALL Servers selected for step
#  copies all the standard properties and prefixed properties(ENV_) to environment variables
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
#
#---------------------- Arguments --------------------------#
###
# WATIR Script Name:
#   name: path to watir script (in script library)
#   type: in-text
#   position: A1:F1
###

#---------------------- Declarations -----------------------#
require 'erb'
params["direct_execute"] = "yes"
#require 'C:/BMC/persist/automation_libs/brpm_framework.rb'
require '/opt/bmc/persist/automation_lib/brpm_framework.rb'

#---------------------- Methods ----------------------------#

# Wrapper to launch ruby and call the watir script

wrapper =<<-END
REM Batch script to call Ruby and WATIR
  <% transfer_properties.each do |prop, val| %>
    <%=set #{prop}=#{val} %>
  <% end %>
cd %RPM_CHANNEL_ROOT%
echo Executing WATIR Script
echo Script: %script_name%
echo Init ruby
%ruby_env_script%
jruby %script_name%
END

#---------------------- Variables --------------------------#
script_path = @p.get("Watir Script Name")
script_name = File.basename(script_path)
library_action = File.join(ACTION_LIBRARY_PATH, script_path)
servers = @rpm.get_server_list
cur_server = servers.keys.first
os = server[cur_server]["os_platform"]
brpm_path = "C:\\Program Files\\BMC Software\\RLM"
transfer_properties = {}

#---------------------- Main Body --------------------------#
# Note RPM_CHANNEL_ROOT will be set in the run script routine

@rpm.message_box "Watir script testing: #{script_name}", "title"
@rpm.log "Location: #{library_action}"
transfer_properties["script_name"] = script_name
transfer_properties["ruby_env_script"] = "#{brpm_path}\\bin\\setenv.bat"
transfer_properties["script_name"] = script_name

action_txt = ERB.new(script).result(binding)
script_file = @transport.make_temp_file(action_text, os)
result = @transport.execute_script(script_file, {"transfer_properties" => transfer_properties })
len = result.length
@rpm.log result if len < 32000
@rpm.log "#{result[0..32000]}\n[truncated]\n#{result[(len-1000)..len]}" if len > 32000

unless find_text == ""
  if result.include?(find_text)
    @rpm.log "Success - found: #{find_text}"
  else
    raise "ERROR - could not find #{find_text} in log"
  end
end


