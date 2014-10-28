# Wrapper for BRPD Script
#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
# Properties will automatically be pushed to env variables if prefixed with the ARG_PREFIX = "ARG_"
ARG_PREFIX = "ENV_"
@p.assign_local_param("SS_automation_category") = "Windows-Powershell" # Assume we can get this into params

#----------------- HERE IS THE BRPD SCRIPT -----------------------#
script =<<-END
#![.ps1]powershell.exe -ExecutionPolicy Unrestricted -File
#############################################################################
# Copyright @ 2012-2014 BMC Software, Inc.                                  #
# This script is supplied as a template for performing the defined actions  #
# via the BMC Release Package and Deployment. This script is written        #
# to perform in most environments but may require changes to work correctly #
# in your specific environment.                                             #
#############################################################################
"Getting environment variables"
Get-ChildItem Env:
END

# This will execute the brpd action
run_brpd_action(script)
