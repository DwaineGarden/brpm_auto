#---------------------- f2_jira_updateStatus -----------------------#
# Description: Updates the status of a Jira issue
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 

#---------------------- Arguments --------------------------#
###
# issue_id:
#   name: id of jira issue
#   position: A1:F1
#   type: in-text
# comment:
#   name: Additional comment for issue
#   position: A2:F2
#   type: in-text
###

#=== Jira Integration Server: JIRA ===#
# [integration_id=1]
SS_integration_dns = "http://WS058837"
SS_integration_username = "jira_user"
SS_integration_password = "-private-"
SS_integration_details = ""
SS_integration_password_enc = "__SS__Cj09UU1MRjBWVGxrVg=="
#=== End ===#

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
require "#{FRAMEWORK_DIR}/brpm_framework"
rpm_load_module("ticket")

#---------------------- Methods ----------------------------#
def map_stage_to_issue_status(stage)
  case stage
    when "DEV"
      return "Ready for Systest"
    when "SYS"
      return "Ready for SIT"
    when "SIT"
      return "Ready for UAT"
    when "UAT"
      return "Ready for Pre Prod"
    when "Preprod"
      return "Ready for Prod"
    #when "Production"
    #  return "done"
    else
      return nil
  end
end

#---------------------- Variables --------------------------#
issue_ids = @p.get("issue_id").split(",")
issue_ids = [@p.get("jira_issue_id")] if issue_ids[0] == ""
issue_ids = @p.tickets_foreign_ids.split(",").map{|l| l.strip } if issue_ids[0] == ""
comment = "RLM Request #{@p.request_id} - Step: #{@p.step.name} \nDeployed #{@p.SS_application} => #{@p.SS_environment} on #{@rpm.precision_timestamp}"
comment += "\n#{@p.comment}" unless @p.comment == ""
target_transition = map_stage_to_issue_status(@p.request_plan_stage)

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion
@jira = Jira::Client.new(SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc), SS_integration_dns)
@rpm.message_box "Adding comment to issue(s): #{issue_ids.join(",")}"
cookie = @jira.login
issue_ids.each do |issue_id|
	transitions = @jira.get_issue_transitions(issue_id)
	transition_id = nil
	transitions["transitions"].select{|item| transition_id = item["id"] if item["name"] == target_transition }
	@rpm.log "ERROR: no state transition available for #{@p.SS_environment}" if transition_id.nil?
	result = @jira.create_comment(issue_id, comment)
	@rpm.log "Jira results:\n#{result.inspect}"
	result = @jira.post_issue_transition(issue_id, transition_id) if transition_id
	@rpm.log "Jira results:\n#{result.inspect}" if transition_id
end


