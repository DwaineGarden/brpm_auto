# = BRPM Automation Framework
# == Customer Include Automation
#    BMC Software - BJB 9/16/2014
# ===== Use this routine to override and provide global methods for all your automation

# set your own automation token
Token = "a56d64cbcffcce91d306670489fa4cf51b53316c" #decrypt_string_with_prefix(@params["SS_api_token"])
# Hostname so nsh paths can be constructed from local paths
BAA_RPM_HOSTNAME = "ip-172-31-45-229.ec2.internal"
# Change this to set BAA base path 
BAA_BASE_PATH = "/opt/bmc/bladelogic"
# This is the root path for use in BAA/BSA
BAA_BASE_GROUP = "BRPM"
# The location and name of the standard NSH script for script execution
BAA_FRAMEWORK_NSH_SCRIPT = "/BRPM/NSHScripts/FrameworkScriptExecute"
# This path will get any files staged by the framework
RPM_STAGING_PATH = "/Users/brady/Documents/dev_rpm/scripts/staging"


# Place your own global constants
DATA_CENTER_NAMES = ["HOU", "LEX", "PUNE"]


