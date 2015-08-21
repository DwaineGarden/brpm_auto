################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_artifactPackagingSvn -----------------------#
# Description: Stage Artifacts on RPM Server and Package for Deployment
#  End any path with a / to get the entire directory
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
require "#{FRAMEWORK_DIR}/brpm_framework"
#
#---------------------- Arguments --------------------------#
###
# svn_url:
#   name: url for svn access (optional if url in VersionTag)
#   type: in-text
#   position: A1:F1
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
###

#---------------------- Declarations -----------------------#
#=> The integration section is only necessary for baa or nsh transport where a credential is required
#=== BMC Application Automation Integration Server: EC2 BSA Appserver ===#
# [integration_id=5]
SS_integration_dns = "https://ip-172-31-36-115.ec2.internal:9843"
SS_integration_username = "BLAdmin"
SS_integration_password = "-private-"
SS_integration_details = "role: BLAdmins
authentication_mode: SRP
profile: defaultProfile"
SS_integration_password_enc = "__SS__Cj09d1lwZDJic1ZHWmh4bVk="
#=== End ===#
@baa.set_credential(SS_integration_dns, SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc), @rpm.get_integration_details("role")) if @p.get("SS_transport", @p.ss_transport) == "baa"
@nsh.set_credential(@rpm.get_integration_details("profile"), SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc)) if @p.get("SS_transport", @p.ss_transport) == "nsh"

rpm_load_module("scm")

#---------------------- Methods ----------------------------#
def fetch_from_svn(svn_url)
  svn_path = get_integration_details("svn_path")
  cmd_options = get_integration_details("options")
  prerun_lines = get_integration_details("prerun")
  svn_stage = "/tmp/svn_#{@p.SS_run_key}"
  FileUtils.mkdir(svn_stage)
  svn_options = {"url" => svn_url, "base_path" => svn_stage, "username" => SS_integration_username, "password" => decrypt_string_with_prefix(SS_integration_password_enc), "command_options" => cmd_options, "prerun_lines" => prerun_lines, "verbose" => true}
  @svn = Svn.new(svn_path, @params, svn_options)
  result = @svn.export
  @rpm.log "Svn export results: #{result}"
  contents = Dir.entries(svn_stage)
  contents.reject{|l| [".", ".."].include?(l) }.map{|k| File.join(svn_stage, k)}
end

#---------------------- Variables --------------------------#
   
#---------------------- Main Body --------------------------#
@rpm.message_box "Gathering artifacts from Svn", "title"
#svn_url = @p.get("svn_url", @p.get("step_version_artifact_url"))
svn_url = @p.get("svn_url", @p.get("#{@p.SS_component}_SVN_URL"))
raise "ERROR: No svn url specified" if svn_url == ""
files_to_deploy = fetch_from_svn(svn_url)
transfer_properties = @transport.get_transfer_properties
result = @transport.package_artifacts(files_to_deploy, {"version" => @p.step_version, "transfer_properties" => transfer_properties})
#@rpm.log "SRUN Result: #{result.inspect}"
@p.assign_local_param("instance_#{@p.SS_component}_content", files_to_deploy)
@p.assign_local_param("instance_#{@p.SS_component}", result)
@rpm.log "Saved in JSON Params: #{"instance_#{@p.SS_component}"}"
@p.save_local_params
pack_response("output_status", "Successfully packaged - #{File.basename(result["instance_path"])}")

params["direct_execute"] = true #Set for local execution

