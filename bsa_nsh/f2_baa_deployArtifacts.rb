#---------------------- f2_baa_deployArtifacts -----------------------#
# Description: Deploys a bl_package created in packaging step
#  Consumes properties:
#    @p.util_brpm_host_name 

#---------------------- Arguments --------------------------#
###
# job_name:
#   name: Job (manual name as override)
#   type: in-text
#   position: A1:C1
#   required: no
# execute_now:
#   name: Execute immediately
#   type: in-list-single
#   list_pairs: yes,yes|no,no
#   position: A2:C2
# BAA_BASE_PATH:
#   name: Base path for source files (all paths are relative to this)
#   type: in-text
#   position: A4:E4
#   required: yes
# job_status:
#   name: Job Status
#   type: out-text
#   position: A1:C1
# target_status:
#   name: Target Status
#   type: out-table
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

#=> ------------- IMPORTANT ------------------- <=#
#- the package_id comes from the JSON params set in packaging step
baa_package_id = @p.get("package_id_#{@p.SS_component}")
#- using the servers assigned to the step
servers = @p.servers.split(",").collect{|s| s.strip}
#- construction of master path in BladeLogic
group_path = "/BRPM/#{@p.SS_application}/#{@p.SS_component}/#{@p.SS_environment}"
#- Item_name is the same for template, package and job and based on component version
component_version = @p.get("SS_component_version")
artifact_paths = @auto.split_nsh_path(@p.step_version_artifact_url)
item_name = component_version == "" ? "#{@p.SS_component}_#{@p.request_id}_#{@timestamp}" : "#{@p.SS_component}_#{@p.request_id}_#{component_version}"
# override item name if specified
item_name = @p.get("job_name", item_name)
#=> ------------------------------------------- <=#

#=> Abstract all the BAA integration variables
baa_config = YAML.load(SS_integration_details)
baa_password = decrypt_string_with_prefix(SS_integration_password_enc)
baa_role = baa_config["role"]

#=> Choose to execute or save job for later
execute_now = @p.get("execute_now", "yes") == "yes"

#---------------------- Main Body --------------------------#
@auto.message_box "Creating/Executing Package Job", "title"

# Deploy the package created to the targets
@baa = BAA.new(SS_integration_dns, SS_integration_username, baa_password, baa_role, {"output_file" => @p.SS_output_file})
session_id = @baa.session_id

options = {"properties" => @params.select{|l,v| l.start_with?("BAA_") }, "execute_now" => true }
job_result = @baa.deploy_package(item_name, baa_package_id, group_path, servers, options)
@auto.log job_result.inspect
pack_response "job_status", job_result["status"]
if job_result.has_key?("target_status")
  table_data = [['', 'Target Type', 'Name', 'Had Errors?', 'Had Warnings?', 'Need Reboot?', 'Exit Code']]
  target_count = 0
  job_result["target_status"].each_pair do |k3, v3|
    v3.each_pair do |k1, v1|
      table_data << ['', k3, k1, v1['HAD_ERRORS'], v1['HAD_WARNINGS'], v1['REQUIRES_REBOOT'], v1['EXIT_CODE*']]
      target_count = target_count + 1
    end
  end
  pack_response "target_status", {:totalItems => target_count, :perPage => '10', :data => table_data }
end
log_file_path = File.join(@p.SS_output_dir, "baa_#{job_result["job_run_id"]}.log")
results_csv = @baa.export_deploy_job_results(group_path, item_name, job_result["job_run_id"], log_file_path)
if results_csv
  pack_response "job_log", log_file_path
else
  @auto.log("Could not fetch job results...")
end


#=> IMPORTANT - here is where we store the job_id for the other steps
@p.assign_local_param("job_id_#{@p.SS_component}", job_result["job_db_key"])
@p.assign_local_param("job_run_url_#{@p.SS_component}", job_result["job_run_url"])
@p.save_local_params



