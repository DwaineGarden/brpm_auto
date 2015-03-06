#---------------------- f2_jira_addComment -----------------------#
# Description: Direct execute on the command line
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
require params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")

#---------------------- Arguments --------------------------#
###
# issue_id:
#   name: id of deployment tracker issue
#   position: A1:F1
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
issue_ids = @p.get("jira_issue_ids") if issue_ids == ""
if @p.get("jira_issue") != "" && @p.get("jira_issue").has_key?("key")
  key = @p.get("jira_issue")["key"]
  issue_ids << key unless issue_ids.include?(key)
end
comment = "Successfully deployed to #{@p.SS_environment}"
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


