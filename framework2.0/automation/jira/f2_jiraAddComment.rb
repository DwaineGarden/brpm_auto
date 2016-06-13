#---------------------- f2_jira_addComment -----------------------#
# Description: Direct execute on the command line
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 

#---------------------- Arguments --------------------------#
###
# issue_id:
#   name: id of jira issue (leave blank to use attached tickets)
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
SS_integration_username = "viswak1"
SS_integration_password = "-private-"
SS_integration_details = ""
SS_integration_password_enc = "__SS__Cj09UU1MRjBWVGxrVg=="
#=== End ===#

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
require "#{FRAMEWORK_DIR}/brpm_framework"
rpm_load_module("ticket")

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
issue_ids = [@p.get("issue_id")]
issue_ids = [@p.get("jira_issue_id")] if issue_ids[0] == ""
issue_ids = @p.tickets_foreign_ids.split(",").map{|l| l.strip } if issue_ids[0] == ""
comment = "RLM Request #{@p.request_id} - Step: #{@p.step_name} \nDeployed #{@p.SS_application} => #{@p.SS_environment} on #{@rpm.precision_timestamp}"
comment += "\n#{@p.comment}" unless @p.comment == ""

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion
@jira = Jira::JiraClient.new(SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc), SS_integration_dns)
@rpm.message_box "Updating JIRA Tickets", "title"
cookie = @jira.login
@rpm.log "\tTickets: #{@p.ticket_ids}"
issue_ids.each do |ticket_id|
  @rpm.log "Updating: #{ticket_id}"
  result = @jira.create_comment(ticket_id, comment)
  @rpm.log "Jira results:\n#{result.inspect}"
  @rpm.log result.inspect
end


