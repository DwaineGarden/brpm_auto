#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
#---------------------- f2_jenkinsBuildStatus -----------------------#
# Description: Returns the status of an ongoing jenkins build
# Author(s): 2015 Brady Byrd
#---------------------- Arguments --------------------------#
###
# Jenkins Project:
#   name: Jenkins Project
#   type: in-external-single-select
#   external_resource: f2_rsc_jenkinsJobs
#   position: A2:D2
#   required: no
# Jenkins Build No:
#   name: Build number from Jenkins
#   type: in-text
#   position: A3:C3
#   required: no
###

#=== General Integration Server: DevOps_Jenkins ===#
# [integration_id=2]
SS_integration_dns = "http://vw-aus-rem-dv11.bmc.com:8080"
SS_integration_username = "bbyrd"
SS_integration_password = "-private-"
SS_integration_details = ""
SS_integration_password_enc = "__SS__Cj1Jek1QTjBaTkYyUQ=="
#=== End ===#


#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
require "#{FRAMEWORK_DIR}/brpm_framework.rb"
rpm_load_module "jenkins"

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
ARG_PREFIX = "ARG_"
jenkins_project = @p.get("Jenkins Project", @p.jenkins_project)
jenkins_build_no = @p.get("Jenkins Build No", @p.jenkins_build_no) #if passed from rest
jenkins_build_no = "lastSuccessfulBuild" if jenkins_build_no == ""
download_file = ""
transfer_properties = {}

#---------------------- Main Body --------------------------#
# Set a property in General for each component to deploy 
@rpm.message_box "Staus of Jenkins Build #{jenkins_build_no}", "title"
@rpm.log "Jenkins:\n\tServer: #{SS_integration_dns}\n\tJob: #{jenkins_project}\n\tBuildNo: #{jenkins_build_no}"
@jenkins = Jenkins.new(SS_integration_dns, script_params, {"username" => SS_integration_username, "password" => decrypt_string_with_prefix(SS_integration_password_enc), "job_name" => jenkins_project})
channel_root = @p.get_server_property(cur_server, "CHANNEL_ROOT")
channel_root = "C:\\temp" if channel_root == ""

rest_result = @jenkins.job_build_data(jenkins_build_no)
build_number = rest_result["data"]["number"]
@rpm.log "Artifacts from Build #{build_number}:"
found = false
rest_result["data"]["artifacts"].each do |item| 
  @rpm.log("\t#{item["fileName"]} => #{item["relativePath"]}")
  if logical_list_value(jenkins_artifact_value, item["fileName"])
    found = true 
    download_file = item["fileName"]
  end
end
@p.assign_local_param("jenkins_build_no", build_number)
@p.assign_local_param("instance_#{@p.SS_component}", package_info)
@p.save_local_params # Cleanup and save


