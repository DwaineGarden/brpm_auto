################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_git_pull -----------------------#
# Description: Performs a git pull

#---------------------- Arguments --------------------------#
###
# repository_path:
#   name: repository path
#   position: A1:F1
#   type: in-text
# repository:
#   name: name of remote repo (optional - origin is default)
#   position: A2:C2
#   type: in-text
# branch:
#   name: name of branch (optional - master is default)
#   position: A3:C3
#   type: in-text
# tag:
#   name: name of tag (used instead of branch)
#   position: A4:C4
#   type: in-text
###

#---------------------- Declarations -----------------------#
#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")

#---------------------- Variables --------------------------#
repo_path = @p.get("repository_path")
branch = @p.branch
tag = @p.tag
origin = @p.origin
path_to_git = "/usr/bin/git"
success = ""

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion
git_options = {
  "base_path" => repo_path,
  "verbose" => true
}
git_options["repository"] = origin unless origin == ""
git_options["branch"] = branch unless branch == ""

@auto.message_box "Updating files from Git", "title"
@auto.log "\tRepository: #{repo_path}"
@git = Git.new(path_to_git, git_options)
result = @git.checkout if tag == ""
result = @git.checkout(false, {"tag" => tag }) if tag != ""
@auto.log "Results: #{result}"

# Apply success or failure criteria
if result.index(success).nil?
  write_to "Command_Failed - term not found: [#{@p.get("success")}]\n"
else
  write_to "Success - found term: #{@p.get("success")}\n"
end


params["direct_execute"] = true #Set for local execution

