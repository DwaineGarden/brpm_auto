################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_artifactDeploy -----------------------#
# Description: Deploy Artifacts from Staging to target_servers
# consumes "instance_#{component_name}" from staging step 
# and deploys it to the targets (ALL Servers selected for step)
#
#---------------------- Arguments --------------------------#
###
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
###

#---------------------- Declarations -----------------------#
require 'fileutils'

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
rpm_load_module("nsh", "dispatch_nsh")
nsh_path = defined?(NSH_PATH) ? NSH_PATH : "/opt/bmc/blade8.5/NSH"
nsh = NSHTransport.new(nsh_path, @params)
@srun = NSHDispatcher.new(nsh, @params)

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
brpm_hostname = @rpm["SS_base_url"].gsub(/^.*\:\/\//, "").gsub(/\:\d.*/, "")
# Check if we have been passed a package instance 
staging_info = @p.required("instance_#{@p.SS_component}")
staging_path = staging_info["instance_path"]

#---------------------- Main Body --------------------------#
# Deploy and unzip the package on all targets
raise "Command_Failed: no artifacts staged in #{File.dirname(staging_path)}" if Dir.entries(File.dirname(staging_path)).size < 3

options = {"allow_md5_mismatch" => true}
#=> Call the framework routine to deploy the package instance
result = @srun.deploy_package_instance(staging_info, options)
@rpm.log "SRUN Result: #{result.inspect}"
result.each do |key, val|
  @p.assign_local_param(key, val)
end
@p.save_local_params

pack_response("output_status", "Successfully deployed - #{File.basename(staging_path)}")

params["direct_execute"] = true #Set for local execution
