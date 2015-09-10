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

#---------------------- Variables -----------------------#
url = "http://ec2-54-208-221-146.compute-1.amazonaws.com:4005/brpm"

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion
res = @rpm.semaphore(@p.SS_component)
@amazon_rest = BrpmRest.new(url, params, {"token" => "a56d64cbcffcce91d306670489fa4cf51b53316c"})
if @rpm.semaphore_exists(@p.SS_component)
  @rpm.log "Semaphore #{@p.SS_component} exists, clearing"
  @rpm.semaphore_clear(@p.SS_component)
else
  @rpm.log "ERROR - failed to create semaphore"
end
@rpm.message_box "Rest Exercises", "title"
@rpm.message_box "This server #{@p.SS_base_url}"
@rpm.log "Current Request"
result = @rest.get("requests", @p.SS_request_number.to_i - 1000)
@rpm.log result.inspect

@rpm.message_box "Remote server #{url}"
@rpm.log "Request 1295"
result = @amazon_rest.get("requests", "295")
@rpm.log result.inspect
