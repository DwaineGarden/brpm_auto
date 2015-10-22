################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_promotionStageCleanup -----------------------#
# Description: Cancels all outstanding requests in a stage that are not being promoted
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 

#---------------------- Arguments --------------------------#

#---------------------- Variables --------------------------#
params["direct_execute"] = true #Set for local execution
if @p.request_plan_id == ""
  @rpm.message_box "ERROR: Must be part of a Plan and Stage"
  exit(1)
end
app_name = @p.SS_application
stage_name = @p.request_plan_stage
plan_id = @p.request_plan_id

#---------------------- Main Body --------------------------#
@rpm.message_box "Cleaning up Plan Stage"
plan = @rest.get("plans", plan_id)
plan["data"]["members"].select{|m| 
  m["stage"]["name"] == stage_name && !["cancelled","complete"].include?(m["request"]["aasm_state"]) && m["request"]["number"].to_s == @p.request_number
  }.each do |member|
  cur_id = (member["request"]["number"] - 1000).to_s
  cur_request = @rest.get("requests",cur_id)
  if cur_request["data"]["apps"][0]["name"] == app_name && cur_request["data"]["environment"]["name"] == @p.SS_environment
    @rpm.log "#{cur_id} - #{cur_request["data"]["name"]} - currently: #{cur_request["data"]["aasm_state"]} - cancelling"
    data = {"aasm_event" => "cancel"}
    res = @rest.update("requests",cur_id, data)
    if res["data"]["aasm_state"] != "cancelled"
      @rpm.log "ERROR: failed to cancel request: #{cur_id}"
    end
  end
end
