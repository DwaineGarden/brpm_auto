################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_stageArtifacts -----------------------#
# Description: Stage Artifacts on RPM Server for Deployment
#  End any path with a / to get the entire directory
#
#---------------------- Arguments --------------------------#
###
# uploadfile_1:
#   name: File 1
#   type: in-file
#   position: A1:F1
# uploadfile_2:
#   name: File 2
#   type: in-file
#   position: A2:F2
# nsh_paths:
#   name: NSH Paths to files(comma delimited fully qualified NSH paths)
#   type: in-text
#   position: A3:F3
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
require 'fileutils'

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
url = "http://ec2-54-208-221-146.compute-1.amazonaws.com:4005/brpm"

nsh_path = defined?(NSH_PATH) ? NSH_PATH : "/opt/bmc/blade8.5/NSH"
@srun = SrunDispatcher.new(nsh_path, @params)

#---------------------- Methods ----------------------------#


#---------------------- Variables --------------------------#
artifact_path = @rpm.get_param("step_version_artifact_url", nil)
artifact_paths = @srun.split_nsh_path(artifact_path) unless artifact_path.nil?
path_server = artifact_path.nil? ? "" : artifact_paths[0]
version = @rpm.get_param("SS_component_version", "#{@rpm.get_param("SS_request_number")}_#{@rpm.precision_timestamp}")    
staging_server = @rpm.get_param("staging_server", path_server)
brpm_hostname = @rpm["SS_base_url"].gsub(/^.*\:\/\//, "").gsub(/\:\d.*/, "")

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion
# Build the list of files for the template

files_to_deploy = []
files_to_deploy << @srun.get_attachment_nsh_path(brpm_hostname, @rpm["uploadfile_1"]) if (@rpm["uploadfile_1"] && !@rpm["uploadfile_1"].empty?)
files_to_deploy << @srun.get_attachment_nsh_path(brpm_hostname, @rpm["uploadfile_2"]) if (@rpm["uploadfile_2"] && !@rpm["uploadfile_2"].empty?)

if @rpm["nsh_paths"] != ""
  @rpm["nsh_paths"].split(',').each do |path|
    ans = @srun.split_nsh_path(path)
    staging_server = ans[0] if ans[0].length > 2
    files_to_deploy << "//#{staging_server}#{ans[1]}"
  end
end

# This gets paths from the VersionTag
unless artifact_path.nil?
  artifact_paths[1].split(',').each do |path|
    ans = @srun.split_nsh_path(path)
    staging_server = ans[0] if ans[0].length > 2
    files_to_deploy << "//#{staging_server}#{ans[1]}"
  end
end

result = @srun.stage_files(files_to_deploy, version)
@rpm.log "SRUN Result: #{result.inspect}"
@p.assign_local_param("instance_#{@p.SS_component}", result)
@rpm.log "Saved in JSON Params: #{"instance_#{@p.SS_component}"}"
@p.save_local_params
