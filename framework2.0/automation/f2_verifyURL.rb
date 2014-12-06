################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_verifyURL -----------------------#
# Description: Tests a url and greps for success text

#---------------------- Arguments --------------------------#
###
# Test URL:
#   name: url to check
#   position: A1:F1
#   type: in-text
# success:
#   name: term to in response to indicate success
#   position: A2:D2
#   type: in-text
###

#---------------------- Declarations -----------------------#

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
url = @p.required("Test URL")
success = @p.required("success")

#---------------------- Main Body --------------------------#

options = {"headers" => {:accept => :html, :content_type => :html}, "verbose" => "yes"}
result = @rpm.rest_call(url, "get", options)

# Apply success or failure criteria
if result["data"].include?(success)
  @rpm.log "Success: found term: #{success}"
else
  @rpm.log "Command_Failed - term not found: #{success}"
end


params["direct_execute"] = true #Set for local execution

