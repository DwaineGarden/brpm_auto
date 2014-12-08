#---------------------- f2_baa_artifactDeploy -----------------------#
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

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require "#{@p.SS_script_support_path}/baa_utilities"
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
rpm_load_module("nsh", "baa")

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
baa_package_id = @p.required("package_id_#{@p.SS_component}")
# override item name if specified
item_name = @p.get("job_name")
#=> Choose to execute or save job for later
execute_now = @p.get("execute_now", "yes") == "yes"
#=> Build the properties
properties = {}
@params.select{|l,v| l.start_with?("BAA_") }.each{|k,v| properties[k] = @p.get(k) }
#=> Remap the abstraction property for the deployment path
property_name = "BAA_BASE_PATH" # this will be the property name in the package references ??BAA_BASE_PATH??
properties[property_name] = @p.get("BAA_DEPLOY_PATH", "/mnt/baa/Sales-Billing/DEV")

#---------------------- Main Body --------------------------#
@rpm.message_box "Creating/Executing Package Job", "title"

#=> Initialize framework objects
@baa = BAA.new(SS_integration_dns, SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc), baa_config["role"], @params)
@srun = DispatchBAA.new(@baa, @params)
session_id = @baa.session_id
options = {"properties" => properties, "execute_now" => execute_now }
options["job_name"] = item_name if item_name != ""
#=> Framework call to deploy
job_result = @srun.deploy_package_instance(baa_package_id, options)
@rpm.log job_result.inspect
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
  @rpm.log("Could not fetch job results...")
end


#=> IMPORTANT - here is where we store the job_id for the other steps
@p.assign_local_param("job_id_#{@p.SS_component}", job_result["job_db_key"])
@p.assign_local_param("job_run_url_#{@p.SS_component}", job_result["job_run_url"])
@p.save_local_params

params["direct_execute"] = true #Set for local execution


