################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_stageArtifacts -----------------------#
# Description: Deploy Artifacts from Staging to target_servers
#  
#
#---------------------- Arguments --------------------------#
###
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
require 'fileutils'

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
url = "http://ec2-54-208-221-146.compute-1.amazonaws.com:4005/brpm"

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
artifact_paths = @rpm.split_nsh_path(@rpm["step_version_artifact_url"])
staging_server = @rpm.get_param("staging_server", artifact_paths[0])
brpm_hostname = @rpm["SS_base_url"].gsub(/^.*\:\/\//, "").gsub(/\:\d.*/, "")
staging_path = staging_dir()

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion
# Build the list of files for the template
raise "Command_Failed: no artifacts staged in #{staging_path.gsub("ERROR_")}" if staging_path.start_with?("ERROR_")

@nsh_path = defined?(NSH_PATH) ? NSH_PATH : "/opt/bmc/blade8.5/NSH"
@nsh = NSHTransport.new(@nsh_path, @params)

@rpm.message_box "Copying Files to targets over NSH"
servers = get_server_list(@params)
@rpm.message_box "OS Platform: #{details["name"]}"
raise "Command_Failed: no servers selected" if servers.size == 0
@rpm.log "Targets: #{servers.inspect}"
@rpm.log "\t Target Servers: #{staging_path}"
files_to_deploy.each do |file_path|
  @rpm.log "\t #{file_path}"
  result = @nsh.ncp(nil, src_path, staging_path)
end
