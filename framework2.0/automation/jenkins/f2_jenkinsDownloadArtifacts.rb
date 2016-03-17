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
#require 'C:/BMC/persist/automation_libs/brpm_framework.rb'
require "#{FRAMEWORK_DIR}/brpm_framework.rb"
rpm_load_module "jenkins"

#---------------------- Methods ----------------------------#
# Assign local variables to properties and script arguments
def logical_list_value(arg_value, match_value)
  result = nil
  items = [arg_value]
  return !(match_value =~ /#{arg_value}.*/).nil? unless arg_value =~ /(\sor\s|\sand\s|\,)/
  list_items = arg_value.split(" or ") if arg_value.include?(" or ")
  list_items = arg_value.split(" and ") if arg_value.include?(" and ")
  list_items = arg_value.split(",") if arg_value.include?(",")
  list_items.map{|l| l.strip }.each{|k| 
    result = (match_value =~ /#{k}.*/)
    break if !result.nil?
  }
  !result.nil?
end  

#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
ARG_PREFIX = "ARG_"
jenkins_project = @p.get("Jenkins Project", @p.jenkins_project)
jenkins_build_no = @p.get("Jenkins Build No", @p.jenkins_build_no) #if passed from rest
jenkins_build_no = "lastSuccessfulBuild" if jenkins_build_no == ""
jenkins_artifact_value = @p.required("Jenkins Artifact")
package_name = "jenkins_#{jenkins_build_no}"
staging_dir = @rpm.get_staging_dir(package_name, true)
win_curl = @p.win_curl #"C:\\bmc\\curl.exe"
cur_server = @p.get_server_list.keys.first
raise "No server selected" if cur_server.length < 3
server_info = YAML.load_file("#{LIBRARY_DIR}/configuration/targets/#{cur_server}/server.yml")

download_file = ""
transfer_properties = {}

#---------------------- Main Body --------------------------#
# Set a property in General for each component to deploy 
@rpm.message_box "Artifacts from Jenkins Build", "title"
@rpm.log "Jenkins:\n\tServer: #{SS_integration_dns}\n\tJob: #{jenkins_project}\n\tBuildNo: #{jenkins_build_no}\n\tArtifact: #{jenkins_artifact_value}"
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
raise "ERROR artifact not in list: #{jenkins_artifact}" unless found
@rpm.log "Full Build Results:"
@rpm.log rest_result["data"].inspect
env_type = @p.SS_environment.downcase.include?("sustaining") ? "Sustaining" : "Main"
new_name = "#{env_type}: Regression - #{jenkins_project} - #{build_number}"
res = @rest.update("requests", (@p.request_id.to_i - 1000).to_s, {"request" => {"name" => new_name}})

# New Method out of mem errors trying to download
if false #<100mb files only
  @rpm.log "Downloading file: #{download_file} to #{staging_dir}"
  @jenkins.get_build_artifact(jenkins_build_no, download_file, staging_dir)
  package_info = @nsh.package_staged_artifacts(staging_dir, "#{package_name}.zip")
end
@rpm.log "Downloading #{download_file} from Jenkins on target"
# http://vw-aus-rem-dv11.bmc.com:8080/job/Trunk_BRPM_INSTALLERS/356/artifact/BRPM_Windows_201505220925.zip
url_part = "#{jenkins_build_no}/artifact/#{download_file}"
url = File.join(SS_integration_dns,"job",jenkins_project, url_part)
target_os = @rpm.get_server_list.first[1]["os_platform"]
cmd = "#{win_curl} -X GET #{url} > #{channel_root}\\#{download_file}"
@rpm.log "Command: #{cmd}"
script_file = @transport.make_temp_file(cmd, "windows")
result = @transport.execute_script(script_file, {"transfer_properties" => transfer_properties})
#@rpm.log "cURL Output: #{result}"
package_info = {"instance_path" => File.join(channel_root, download_file)}

exit_status = @rpm.verify_success_terms(result, "Xferd")
regression_log_from_master(!exit_status.include?("Command_Failed"), exit_status[0..160])

version_name = download_file.match(/RLM_.*_BRPM/)
unless version_name.nil? && false # Try to stick with a static version name
  file_release = download_file.match(/RLM_.*_BRPM/).to_s.gsub(/RLM_|_BRPM/,"")
  @p.assign_local_param("rpm_install_release", file_release) if file_release.include?(@p.rpm_target_release)
end

@p.assign_local_param("brpm_target_server", cur_server)
@p.assign_local_param("target_#{@p.SS_component}", @p.get_server_list)
@p.assign_local_param("jenkins_build_no", build_number)
@p.assign_local_param("instance_#{@p.SS_component}", package_info)
@p.assign_local_param("jenkins_download_package", download_file)
@p.assign_local_param("target_server_info", server_info)
@p.assign_local_param("target_server_url", server_info["url"])
@p.assign_local_param("target_server_url_base", server_info["url"].gsub("/brpm", ""))
@p.save_local_params # Cleanup and save


