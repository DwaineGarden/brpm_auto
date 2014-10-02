################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_directExecute -----------------------#
# Description: Direct execute on the command line

#---------------------- Arguments --------------------------#
###
# command:
#   name: command to run
#   position: A1:F1
#   type: in-text
# success:
#   name: term to indicate success
#   position: A2:D2
#   type: in-text
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion

result = run_command(params, @p.get("command"),"")

# Apply success or failure criteria
if result.index(@p.get("success")).nil?
  write_to "Command_Failed - term not found: [#{@p.get("success")}]\n"
else
  write_to "Success - found term: #{@p.get("success")}\n"
end
