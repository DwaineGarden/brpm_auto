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
url = "http://ec2-54-208-221-146.compute-1.amazonaws.com:4005/brpm"

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion
@amazon_rest = BrpmRest.new(url, params, {"token" => "a56d64cbcffcce91d306670489fa4cf51b53316c"})

@rpm.message_box "Rest Exercises", "title"
@rpm.message_box "This server #{@rpm["SS_base_url"]}"
@rpm.log "Current Request"
result = @rest.get("requests", @rpm["SS_request_number"].to_i - 1000)
@rpm.log result.inspect

@rpm.message_box "Remote server #{url}"
@rpm.log "Request 1295"
result = @amazon_rest.get("requests", "295")
@rpm.log result.inspect
