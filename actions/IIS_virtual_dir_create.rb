#---------------------- Action Name -----------------------#
# Description: Creates a virtual directory in the IIS system
#---------------------- Arguments --------------------------#
###
# ENV_IIS_VIRDIR_NAME:
#   name: Virtual directory name
#   position: A1:C1
#   type: in-text
# ENV_IIS_VIRDIR_PATH:
#   name: virtual directory path
#   position: A2:F2
#   type: in-text
# ENV_IIS_SITE_NAME:
#   name: site name
#   position: A3:F3
#   type: in-text
###

# Note action script will be processed as ERB!
#----------------- HERE IS THE ACTION SCRIPT -----------------------#
script =<<-END
# ![.ps1]powershell.exe -ExecutionPolicy Unrestricted -File
#############################################################################
# Copyright @ 2012-2014 BMC Software, Inc.                                  #
# This script is supplied as a template for performing the defined actions  #
# via the BMC Release Package and Deployment. This script is written        #
# to perform in most environments but may require changes to work correctly #
# in your specific environment.                                             #
#############################################################################

#
# Creates a virtual directory in the IIS system
#
#   IIS_VIRDIR_NAME		virtual dir name
#   IIS_VIRDIR_PATH		pathname to associate
#   IIS_SITE_NAME		site name hosting app
#
#

# Server 2008 R2 has all the IIS management WMI objects
# installed as defaults.
# For Server 2008 SP2 the following must be installed:
#    Powershell 2.0
#    .Net Framework 3.5
#    IIS 6.0 management compatibility role service
#    IIS Management service

$script:ErrorActionPreference = "Continue"

# Verify current version of PowerShell and working WMI
$psVersion = (get-host -errorvariable pserror).version.major
$wmiVersion = (get-wmiobject Win32_WMISetting -errorvariable wmierror).BuildVersion
if ($psVersion -lt 2 -or $pserror -ne "") {
	"Error:  PowerShell Version 2.0 or later is required."
	exit 1
}
if ($wmierror -ne "") {
	"WMI Error: $wmierror"
	exit 1
}

# Check Variables
if (!($env:IIS_VIRDIR_NAME)) {
	"IIS_VIRDIR_NAME environment variable not set"
	exit(1)
}
if (!($env:IIS_VIRDIR_PATH)) {
	"IIS_VIRDIR_PATH environment variable not set"
	exit(1)
}

$errorBase = $error[0];

$appName = $env:IIS_VIRDIR_NAME;
$appPath = $env:IIS_VIRDIR_PATH;

if ($env:IIS_SITE_NAME -ne $null)  {
#   $website = Get-WmiObject -Namespace 'root\\MicrosoftIISv2' -Class IISWebServerSetting -Filter "ServerComment = '$env:IIS_SITE_NAME'";
    $siteName = "W3SVC/1";
    }
  else {
    $siteName = "W3SVC/1";
}


$newVDirName = $siteName + "/ROOT/" + $appName;

# $virtualDirSettings = [wmiclass] "root\\MicrosoftIISv2:IIsWebVirtualDirSetting";
# $newVDir = $virtualDirSettings.CreateInstance();
# $newVDir.Name = $newVDirName;
# $newVDir.Path = $appPath;
# $newVDir.EnableDefaultDoc = $False;

write-host "Creating new Virtual Directory $appName at path $appPath"

# $newVDir.Put() | out-null;

if($error[0] -ne $errorBase) {
	write-error "Error occurred creating virtual directory $appName"
	exit 1
}

END

wrapper_script = "C:\\windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe  -ExecutionPolicy Unrestricted -File %%"

# === The code below will process the action for execution

#---------------------- Declarations -------------------------#
#=> IMPORTANT  <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
# Properties will automatically be pushed to env variables if prefixed with the ARG_PREFIX
arg_prefix = "ENV_"

#---------------------- Variables ----------------------------#
# Assign local variables to properties and script arguments
automation_category = "powershell"
success = "Virtual Directory"
max_time = (@p.get("step_estimate", "5").to_i) * 60

#---------------------- Main Script --------------------------#

@auto.message_box "Creating IIS Virtual Dir", "title"
@auto.log "\tDirName: #{@p.required("ENV_IIS_VIRDIR_NAME")}"
@auto.log "\tDirPath: #{@p.required("ENV_IIS_VIRDIR_PATH")}"
@auto.log "\tSiteName: #{@p.required("ENV_IIS_SITE_NAME")}"

# This will execute the action
#  execution targets the selected servers on the step, but can be overridden in options
action_options = {
  "automation_category" => automation_category, 
  "property_filter" => arg_prefix, 
  "timeout" => max_time, 
  "debug" => false
  }
@action = Action.new(@p,action_options)

# Execution defaults to nsh transport, you can override with server properties (not implemented yet)
# Options can take several keys for overrides
run_options = {
  "wrapper_script" => wrapper_script
  #"payload" => path_to_payload file to reference e.g. ear/war file
  }
result = @action.run!(script, run_options) 
#@auto.message_box "Results"
#@auto.log @action.display_result(result)
@auto.log "Command_Failed: cannot find term: [#{success}]" unless result["stdout"].include?(success)

params["direct_execute"] = "yes"
