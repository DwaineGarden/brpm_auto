# Description: Download an artifact from jenkins
#  Instructions: Modify this automation for each flavor of application deployment
#    add any arguments you want to be available to other steps here by prefixing them with "ARG_"
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
#---------------------- f2_getRequestInputs_basic -----------------------#
# Description: Enter Request inputs for component deploy and promotion
# Author(s): 2015 Brady Byrd
#---------------------- Arguments --------------------------#
###
# Jenkins Artifact:
#   name: Artifact to download from Jenkins
#   type: in-text
#   position: A1:D1
#   required: no
# Jenkins Project:
#   name: Jenkins Project
#   type: in-external-single-select
#   external_resource: f2_rsc_jenkinsProjects
#   position: A2:D2
#   required: no
# Jenkins Build No:
#   name: Build number from Jenkins
#   type: in-text
#   position: A3:C3
#   required: no
###

#=== General Integration Server: RLMJenkins ===#
# [integration_id=10020]
SS_integration_dns = "http://vw-aus-rem-dv11.bmc.com:8080"
SS_integration_username = "bbyrd"
SS_integration_password = "-private-"
SS_integration_details = ""
SS_integration_password_enc = "__SS__Cj1Jek1QTjBaTkYyUQ=="
#=== End ===#

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
require 'C:/BMC/persist/automation_libs/brpm_framework.rb'
rpm_load_module "jenkins"

#---------------------- Methods ----------------------------#
# Assign local variables to properties and script arguments

#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
ARG_PREFIX = "ARG_"
jenkins_project = @p.get("Jenkins Project", @p.jenkins_project)
jenkins_build_no = @p.get("Jenkins Build No", @p.jenkins_build_no) #if passed from rest
jenkins_artifact = @p.required("Jenkins Artifact")
package_name = "jenkins_#{jenkins_build_no}"
staging_dir = @rpm.get_staging_dir(package_name, true)

#---------------------- Main Body --------------------------#
# Set a property in General for each component to deploy 
@rpm.message_box "Artifacts from Jenkins Build", "title"
@rpm.log "Jenkins:\n\tServer: #{SS_integration_dns}\n\tJob: #{jenkins_project}\n\tBuildNo: #{jenkins_build_no}\n\tArtifact: #{jenkins_artifact}"
@jenkins = Jenkins.new(SS_integration_dns, script_params, {"username" => SS_integration_username, "password" => decrypt_string_with_prefix(SS_integration_password_enc), "job_name" => jenkins_project})
rest_result = @jenkins.job_build_data(jenkins_build_no)
@rpm.log "Artifacts:"
found = false
rest_result["data"]["artifacts"].each do |item| 
  @rpm.log("\t#{item["fileName"]} => #{item["relativePath"]}")
  found = true if item["fileName"] == jenkins_artifact
end
raise "ERROR artifact not in list: #{jenkins_artifact}" unless found
@rpm.log "Full Build Results:"
@rpm.log rest_result["data"].inspect

@rpm.log "Downloading file: #{jenkins_artifact} to #{staging_dir}"
@jenkins.get_build_artifact(jenkins_build_no, jenkins_artifact, staging_dir)
package_info = @nsh.package_staged_artifacts(staging_dir, "#{package_name}.zip")

@p.assign_local_param("instance_#{@p.SS_component}", package_info)
@p.save_local_params # Cleanup and save


