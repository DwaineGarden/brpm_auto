################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_artifactPackaging -----------------------#
# Description: Stage Artifacts on RPM Server and Package for Deployment
#  End any path with a / to get the entire directory
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
require "#{FRAMEWORK_DIR}/brpm_framework"
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
# artifact_paths:
#   name: Paths to files(comma delimited fully qualified paths)
#   type: in-text
#   position: A3:F3
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
###

#---------------------- Declarations -----------------------#
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
@nsh.set_credential(@rpm.get_integration_details("profile"), SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc)) if defined?(SS_integration_dns) && @p.get("SS_transport", @p.ss_transport) == "nsh"

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion
# Build the list of files for the template
files_to_deploy = @transport.get_artifact_paths(@p, options = {})
transfer_properties = @transport.get_transfer_properties
result = @transport.package_artifacts(files_to_deploy, {"version" => @p.step_version, "transfer_properties" => transfer_properties})
raise "Command_Failed: No artifacts in staging area" if result["instance_path"].start_with?("ERROR")
#@rpm.log "SRUN Result: #{result.inspect}"
@p.assign_local_param("instance_#{@p.SS_component}_content", files_to_deploy)
@p.assign_local_param("instance_#{@p.SS_component}", result)
@rpm.log "Saved in JSON Params: #{"instance_#{@p.SS_component}"}"
@p.save_local_params
pack_response("output_status", "Successfully packaged - #{File.basename(result["instance_path"])}")

params["direct_execute"] = true #Set for local execution

