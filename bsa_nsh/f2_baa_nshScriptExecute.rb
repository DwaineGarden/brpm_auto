#---------------------- f2_baa_nshScriptExecute -----------------------#
# Description: Executes an nsh script via BSA
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

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
rpm_load_module("nsh", "baa")
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
nsh_script_path = @p.get("NSH_DEPLOY_SCRIPT")
nsh_script_name = File.basename(nsh_script_path)
#=> Choose to execute or save job for later
execute_now = @p.get("execute_now", "yes") == "yes"
#=> Build the properties
job_params = []

#---------------------- Main Body --------------------------#
@rpm.message_box "Executing NSHScript Job - #{nsh_script_name}", "title"
#=> Initialize framework objects
@baa = BAA.new(SS_integration_dns, SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc),baa_config["role"],@params)
@srun = DispatchBAA.new(@baa, @params)
session_id = @baa.session_id
@rpm.log "JobParams to transfer:"
# add standard RPM properties
["SS_application", "SS_component", "SS_environment", "SS_component_version", "SS_request_number"].each do |prop|
  job_params << @p.get(prop)
  @rpm.log "#{prop} => #{@p.get(prop)}"
end
version_dir = "#{@p.get("BAA_DEPLOY_PATH")}/#{@p.SS_application}/#{@p.step_version}"
@rpm.log "VERSION_DIR => #{version_dir}"
job_params << version_dir

options = {"execute_now" => true }
#=> Call the job creation/execution from the framework
job_result = @srun.create_nsh_script_job(nsh_script_name, File.dirname(nsh_script_path), job_params, options)
@rpm.log job_result.inspect
pack_response "job_status", job_result["status"]
log_file_path = File.join(@p.SS_output_dir, "baa_#{job_result["job_run_id"]}.log")


#=> IMPORTANT - here is where we store the job_id for the other steps
# @p.save_local_params

params["direct_execute"] = true #Set for local execution


