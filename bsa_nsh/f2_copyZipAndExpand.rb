#---------------------- Action Name -----------------------#
# Description: Creates a virtual directory in the IIS system
#---------------------- Arguments --------------------------#
###
# ENV_ZIP_ARCHIVE_PATH:
#   name: nsh path to zip file
#   position: A1:F1
#   type: in-text
# ENV_TARGET_PATH:
#   name: directory path relative to base
#   position: A2:F2
#   type: in-text
###

# Note action script will be processed as ERB!
#----------------- HERE IS THE ACTION SCRIPT -----------------------#
script_bash =<<-END
#!/bin/bash
# Uses ENV Variables
#
#    TARGET_PATH
#
ZIP_NAME=<%=File.basename(@p.ENV_ZIP_ARCHIVE_PATH) %>
echo "#--------- UNZIPPING ------------#"
echo "# File: ${ZIP_NAME}"
echo "# Target: ${TARGET_PATH}"
cd $TARGET_PATH
/usr/bin/unzip $ZIP_NAME
END


script_powershell =<<-END
# Uses ENV Variables
#
#    TARGET_PATH
#
$zip_name="<%=File.basename(@p.ENV_ZIP_ARCHIVE_PATH) %>"

# Check Variables
if (!($env:TARGET_PATH)) {
	"TARGET_PATH environment variable not set"
	exit(1)
}

write-host "#--------- UNZIPPING ------------#"
write-host "# File: $zip_name"
write-host "# Target: $Env:TARGET_PATH"
cd $Env:TARGET_PATH
$shell = new-object -com shell.application
$zip = $shell.NameSpace("$Env:TARGET_PATH\\$zip_name")
foreach($item in $zip.items())
{
  $shell.Namespace("$Env:TARGET_PATH").copyhere($item)
}
END

wrapper_script = "C:\\windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe  -ExecutionPolicy Unrestricted -File %%"

# === The code below will process the action for execution

#---------------------- Declarations -------------------------#
#=> IMPORTANT  <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
# Properties will automatically be pushed to env variables if prefixed with the ARG_PREFIX
params["inline_execute"] = "yes"

#---------------------- Variables ----------------------------#
# Assign local variables to properties and script arguments
arg_prefix = "ENV_"
success = "UNZIPPING"
max_time = (@p.get("step_estimate", "5").to_i) * 60
zip_archive = @p.required("ENV_ZIP_ARCHIVE_PATH")

#---------------------- Main Script --------------------------#

@auto.message_box "Copy and Unzip Files", "title"
@auto.log "\tDirName: #{@p.get("ENV_ZIP_ARCHIVE_PATH")}"
@auto.log "\tDirPath: #{@p.required("ENV_TARGET_PATH")}"
@nsh = NSH.new(NSH_PATH)
# This will execute the action
#  execution targets the selected servers on the step, but can be overridden in options
  action_options = {
    "automation_category" => "general_bash", 
    "property_filter" => arg_prefix, 
    "timeout" => max_time, 
    "debug" => false
    }
  # Execution defaults to nsh transport, you can override with server properties (not implemented yet)
  # Options can take several keys for overrides
  run_options = {}
   
# Loop through the servers by plaform
result = []
["linux", "windows"].each do |os|
  servers = @p.server_list.select{|serv,props| props["os_platform"].downcase =~ /#{os}/ }
  next if servers.size == 0
  action_options["automation_category"] = "general_powershell" if os == "windows"
  run_options["servers"] = servers
  @action = Action.new(@p,action_options)
  channel_root = @action.get_channel_root(servers[0], os)
  payload_path = File.join(channel_root, base_path, zip_archive)
  copy_result = @nsh.ncp(servers, src_path, target_path)
  if os == "windows"
    script = script_powershell
    run_options["wrapper_script"] = wrapper_script
    run_options["payload"] = @action.dos_path(payload_path)
  else
    script = script_bash
    run_options["payload"] = payload_path
  end  
  result << @action.run!(script, run_options) 
end
#@auto.message_box "Results"
#@auto.log @action.display_result(result)
result.each do |status|
  if display_result(status).include?(success)
    @auto.log "Success found term: [#{success}]"
  else
    @auto.log "Command_Failed: cannot find term: [#{success}]" 
  end
end

params["direct_execute"] = "yes"
