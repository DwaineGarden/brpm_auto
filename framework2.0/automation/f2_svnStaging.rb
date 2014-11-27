################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_artifactStaging -----------------------#
# Description: Stage Artifacts on RPM Server for Deployment
#  from an Svn source
#
#---------------------- Arguments --------------------------#
###
# Svn Target:
#   name: Svn path to checkout
#   type: in-text
#   position: A1:F1
# Svn Revision:
#   name: revision to checkout
#   type: in-text
#   position: A2:F2
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
###

#---------------------- Integration Header (do not modify) -----------------------#
#=== General Integration Server: SVN ===#
# [integration_id=6]
SS_integration_dns = "https://svn.nam.nsroot.net:9050"
SS_integration_username = "rlm_user"
SS_integration_password = "-private-"
SS_integration_details = "svn_path: /export/opt/svn/1.7.5/opt/CollabNet_Subversion
svn_options: --no-auth-cache --trust-server-cert --force --non-interactive
env_variables: LD_LIBRARY_PATH=/export/opt/svn/1.7.5/opt/CollabNet_Subversion/lib"
SS_integration_password_enc = "__SS__Cj1JWFp6VjNYdHhtYw=="
#=== End ===#

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
require 'fileutils'

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
rpm_load_module("nsh", "dispatch_nsh", "scm")

nsh_path = defined?(NSH_PATH) ? NSH_PATH : "/opt/bmc/blade8.5/NSH"
@srun = NSHDispatcher.new(nsh_path, @params)
#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
integration_details = get_integration_details(SS_integration_details)
version = @p.get("step_version")    
version = "#{@p.get("SS_request_number")}_#{@rpm.precision_timestamp}" if version == ""
artifact_path = @p.get("step_version_artifact_url", nil)
brpm_hostname = @p.SS_base_url.gsub(/^.*\:\/\//, "").gsub(/\:\d.*/, "")
svn_target = @p.get("Svn Target", @p.svn_target)
svn_revision = @p.get("Svn Revision", @p.svn_revision)
staging_path = @srun.get_staging_dir(version, true)

#---------------------- Main Body --------------------------#
svn_url = artifact_path.nil? ? SS_integration_dns : artifact_path
svn_url = svn_target if svn_target.include?("://")
svn_options = {"url" => svn_url,
  "base_path" => staging_path,
  "username" => SS_integration_username,
  "password" => SS_integration_password,
  "verbose" => true,
  "simulate" => true,
  "prerun_lines" => integration_details["env_variables"],
  "command_options" => integration_details["svn_options"]
  }
@svn = Svn.new(integration_details["svn_path"], @params, svn_options)
url_parts = @svn.parse_uri(svn_url, true)
svn_target = url_parts["uri_result"].path
@rpm.private_password[url_parts["uri_result"].password] unless url_parts["uri_result"].password.nil?

raise "Command_Failed: no svn target to checkout" if svn_target == ""
@rpm.message_box "Copying Files to Staging via Subversion"
@rpm.log "\t StagingPath: #{staging_path}"
@rpm.log "\t SubversionURL: "    
result = @svn.export(svn_target)

result = @srun.package_files(staging_path, version)
@rpm.log "SRUN Result: #{result.inspect}"
@p.assign_local_param("instance_#{@p.SS_component}", result)
@rpm.log "Saved in JSON Params: #{"instance_#{@p.SS_component}"}"
@p.save_local_params
pack_response("output_status", "Successfully packaged - #{File.basename(result["instance_path"])}")
