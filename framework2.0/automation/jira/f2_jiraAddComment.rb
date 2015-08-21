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
SS_integration_username = "viswak1"
SS_integration_password = "-private-"
SS_integration_details = ""
SS_integration_password_enc = "__SS__Cj09UU1MRjBWVGxrVg=="
#=== End ===#

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
@rpm_load_module("ticket")

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
issue_id = @p.get("issue_id")
issue_id = @p.get("jira_issue_id") if issue_id == ""
comment = "Successfully deployed to #{@p.SS_environment}"

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion
@jira = Jira::Client.new(SS_integration_user, decrypt_string_with_prefix(SS_integration_password_enc), SS_integration_dns)
@rpm.message_box "Adding comment to issue: #{issue_id}"
cookie = @jira.login
result = @jira.create_comment(issue_id, comment)
@rpm.log "Jira results:\n#{result.inspect}"


