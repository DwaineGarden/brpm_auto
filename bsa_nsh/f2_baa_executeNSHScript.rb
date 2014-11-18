#---------------------- f2_baa_executeNSHScript -----------------------#
# Description: Deploys a bl_package created in packaging step
#  Consumes properties:
#    @p.util_brpm_host_name 

#---------------------- Arguments --------------------------#
###
# execute_now:
#   name: Execute the script now or wait
#   type: in-list-single
#   list_pairs: yes,yes|no,no
#   position: A1:C1
# job_status:
#   name: Job status
#   type: out-file
#   position: A2:F2
# job_log:
#   name: Job Log
#   type: out-file
#   position: A3:F3
# job_log_html:
#   name: Job Log HTML
#   type: out-file
#   position: A4:F4
###

#=== BMC Application Automation Integration Server: EC2 BSA Appserver ===#
## [integration_id=5]
SS_integration_dns = "https://ip-10-83-51-52:9843/"
SS_integration_username = "BLAdmin"
SS_integration_password = "-private-"
SS_integration_details = "role: BLAdmins
authentication_mode: SRP"
SS_integration_password_enc = "__SS__Cj09d1lwZDJic1ZHWmh4bVk="
#=== End ===#

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")

require "#{@p.SS_script_support_path}/baa_utilities"

#---------------------- Methods ----------------------------#
# Assign local variables to properties and script arguments


#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
#=> Abstract all the BAA integration variables
baa_config = YAML.load(SS_integration_details)
baa_password = decrypt_string_with_prefix(SS_integration_password_enc)
baa_role = baa_config["role"]

#=> ------------- IMPORTANT ------------------- <=#
#- the package_id comes from the JSON params set in packaging step
baa_package_id = @p.get("package_id_#{@p.SS_component}")
#- using the servers assigned to the step
servers = @p.servers.split(",").collect{|s| s.strip}
#- construction of master path in BladeLogic
group_path = "/BRPM/#{@p.SS_application}/#{@p.SS_component}/#{@p.SS_environment}"
#- Item_name is the same for template, package and job and based on component version
component_version = @p.get("SS_component_version")
item_name = component_version == "" ? "#{@p.SS_component}_#{@p.request_id}_#{@timestamp}" : "#{@p.SS_component}_NSH_#{@p.request_id}_#{component_version}"
nsh_script_path = @p.get("NSH_DEPLOY_SCRIPT")
nsh_script_name = File.basename(nsh_script_path)
#=> Choose to execute or save job for later
execute_now = @p.get("execute_now", "yes") == "yes"
#=> Build the properties
job_params = []

#---------------------- Main Body --------------------------#
@auto.message_box "Executing NSHScript Job - #{nsh_script_name}", "title"
@auto.log "JobParams to transfer:"
# add standard RPM properties
["SS_application", "SS_component", "SS_environment", "SS_component_version", "SS_request_number"].each do |prop|
  job_params << @p.get(prop)
  @auto.log "#{prop} => #{@p.get(prop)}"
end
version_dir = "#{@p.get("BAA_DEPLOY_PATH")}/#{@p.SS_application}/#{@p.SS_component_version}"
@auto.log "VERSION_DIR => #{version_dir}"
job_params << version_dir
# Deploy the package created to the targets
@baa = BAA.new(SS_integration_dns, SS_integration_username, baa_password, baa_role, {"output_file" => @p.SS_output_file})
session_id = @baa.session_id

options = {"execute_now" => true }
job_result = @baa.create_nsh_script_job(item_name, group_path, nsh_script_name, File.dirname(nsh_script_path), job_params, servers, options)
@auto.log job_result.inspect
pack_response "job_status", job_result["status"]
log_file_path = File.join(@p.SS_output_dir, "baa_#{job_result["job_run_id"]}.log")


#=> IMPORTANT - here is where we store the job_id for the other steps
# @p.save_local_params



