################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_artifactStaging -----------------------#
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
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
###

#---------------------- Declarations -----------------------#
require 'fileutils'

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
rpm_load_module("nsh", "dispatch_nsh")

nsh_path = defined?(NSH_PATH) ? NSH_PATH : "/opt/bmc/blade8.5/NSH"
nsh = NSHTransport.new(nsh_path, @params)
@srun = NSHDispatcher.new(nsh, @params)

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion
# Build the list of files for the template
files_to_deploy = @srun.get_artifact_paths(@p, options = {})
result = @srun.package_artifacts(files_to_deploy, @p.step_version)
#@rpm.log "SRUN Result: #{result.inspect}"
@p.assign_local_param("instance_#{@p.SS_component}_content", files_to_deploy)
@p.assign_local_param("instance_#{@p.SS_component}", result)
@rpm.log "Saved in JSON Params: #{"instance_#{@p.SS_component}"}"
@p.save_local_params
pack_response("output_status", "Successfully packaged - #{File.basename(result["instance_path"])}")

params["direct_execute"] = true #Set for local execution

