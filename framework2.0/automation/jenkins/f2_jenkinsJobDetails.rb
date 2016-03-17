# Description: Display Job details from jenkins
#  Instructions: Modify this automation for each flavor of application deployment
#    add any arguments you want to be available to other steps here by prefixing them with "ARG_"
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
#---------------------- f2_jenkinsJobDetails -----------------------#
# Author(s): 2016 Brady Byrd
#---------------------- Arguments --------------------------#
###
# Jenkins Project:
#   name: Jenkins Project
#   type: in-external-single-select
#   external_resource: f2_rsc_jenkinsJobs
#   position: A1:D1
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
download_file = ""
transfer_properties = {}

#---------------------- Main Body --------------------------#
# Set a property in General for each component to deploy 
@rpm.message_box "Job Details for #{jenkins_project}", "title"
@rpm.log "Jenkins:\n\tServer: #{SS_integration_dns}\n\tJob: #{jenkins_project}"
@jenkins = Jenkins.new(SS_integration_dns, script_params, {"username" => SS_integration_username, "password" => decrypt_string_with_prefix(SS_integration_password_enc), "job_name" => jenkins_project})

rest_result = @jenkins.job_data
@rpm.log "Build Details:"
@rpm.log rest_result["data"].inspect


