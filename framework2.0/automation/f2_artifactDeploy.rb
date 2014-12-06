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
#=== BMC Application Automation Integration Server: EC2 BSA Appserver ===#
# [integration_id=5]
SS_integration_dns = "https://ip-172-31-36-115.ec2.internal:9843"
SS_integration_username = "BLAdmin"
SS_integration_password = "-private-"
SS_integration_details = "role : BLAdmins
authentication_mode : SRP"
SS_integration_password_enc = "__SS__Cj09d1lwZDJic1ZHWmh4bVk="
#=== End ===#
@baa.set_credential(SS_integration_dns, SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc), get_integration_details("role")) if @p.SS_transport == "baa"

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
brpm_hostname = @p.SS_base_url.gsub(/^.*\:\/\//, "").gsub(/\:\d.*/, "")
# Check if we have been passed a package instance 
staging_info = @p.required("instance_#{@p.SS_component}")
staging_path = staging_info["instance_path"]

#---------------------- Main Body --------------------------#
# Deploy and unzip the package on all targets
transfer_properties = @transport.get_transfer_properties
options = {"allow_md5_mismatch" => true, "transfer_properties" => transfer_properties}
#=> Call the framework routine to deploy the package instance
result = @transport.deploy_package_instance(staging_info, options)
#@rpm.log "SRUN Result: #{result.inspect}"
#@p.save_local_params

pack_response("output_status", "Successfully deployed - #{File.basename(staging_path)}")

params["direct_execute"] = true #Set for local execution
