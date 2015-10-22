################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_directExecute -----------------------#
# Description: Direct execute on the command line
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
require "#{FRAMEWORK_DIR}/brpm_framework"

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

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion

result = run_command(params, @p.get("command"),"")

# Apply success or failure criteria
if result.include?(@p.get("success"))
  @rpm.log "Success - found term: #{@p.get("success")}\n"
else
  @rpm.log "Command_Failed - term not found: [#{@p.get("success")}]\n"
end
