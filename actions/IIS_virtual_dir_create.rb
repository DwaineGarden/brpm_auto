#---------------------- Action Name -----------------------#
# Description: Creates a virtual directory in the IIS system

# Note action script will be processed as ERB!
#----------------- HERE IS THE ACTION SCRIPT -----------------------#
script =<<-END
#![.ps1]powershell.exe -ExecutionPolicy Unrestricted -File
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
    #$website = Get-WmiObject -Namespace 'root\\MicrosoftIISv2' -Class IISWebServerSetting -Filter "ServerComment = '$env:IIS_SITE_NAME'";
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

# === The code below will process the action for execution

#---------------------- Arguments --------------------------#
###
# ARG_IIS_VIRDIR_NAME:
#   name: Virtual directory name
#   position: A1:C1
#   type: in-text
# ARG_IIS_VIRDIR_PATH:
#   name: virtual directory path
#   position: A2:F2
#   type: in-text
# ARG_IIS_SITE_NAME:
#   name: site name
#   position: A3:F3
#   type: in-text
###

#---------------------- Declarations -------------------------#
#=> IMPORTANT  <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
# Properties will automatically be pushed to env variables if prefixed with the ARG_PREFIX
arg_prefix = "ARG_"

#---------------------- Variables ----------------------------#
# Assign local variables to properties and script arguments
automation_category = "powershell"
success = "Virtual Directory"

#---------------------- Main Script --------------------------#
# This will execute the action
#  execution targets the selected servers on the step, but can be overridden in options
#  execution defaults to nsh transport, you can override with server properties (not implemented yet)
options = {} # Options can take several keys for overrides
@action = Action.new(@p,{"automation_category" => automation_category, "property_filter" => arg_prefix, "timeout" => 30, "debug" => false})
result = @action.run!(script, options)

@auto.log "Command_Failed: cannot find: #{success}" unless result["stdout"].include?(success)

params["direct_execute"] = "yes"
