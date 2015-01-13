################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_nshScriptExecute -----------------------#
# Description: Executes a nsh script on target_servers
# For use only with BAA transport:
# Executes on ALL Servers selected for step
#  copies all the standard properties and prefixed properties(ENV_) to environment variables
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
#
#---------------------- Arguments --------------------------#
###
# nsh_script_group_path:
#   name: BAA group path to script_file (fully qualified)
#   type: in-text
#   position: A1:F1
# execute_now:
#   name: Execute the script now or wait
#   type: in-list-single
#   list_pairs: yes,yes|no,no
#   position: A2:C2
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

#---------------------- Declarations -----------------------#
require 'erb'
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
nsh_script_path = @p.get("nsh_script_group_path", @p.get("NSH_DEPLOY_SCRIPT"))
nsh_script_name = File.basename(nsh_script_path)
#=> Choose to execute or save job for later
execute_now = @p.get("execute_now", "yes") == "yes"
baa_deploy_path = @p.required("BAA_DEPLOY_PATH")

#---------------------- Main Body --------------------------#
raise "Command_Failed: No script to execute: #{script_path}" if nsh_script_path == ""
# Note RPM_CHANNEL_ROOT will be set in the run script routine

@rpm.message_box "Executing NSH Script - #{nsh_script_path}"
result = @transport.execute_script(script_file, {"transfer_properties" => transfer_properties, "transfer_prefix" => transfer_prefix })
#@rpm.log "SRUN Result: #{result.inspect}"
exit_status = "Success"
result.split("\n").each{|line| exit_status = line if line.start_with?("EXIT_CODE:") }
pack_response("script_file_to_execute", script_path)
pack_response("output_status", exit_status)
@p.assign_local_param("script_#{@p.SS_component}", script_path)
@p.save_local_params
params["direct_execute"] = true

@rpm.log "JobParams to transfer:"
# add standard RPM properties
["SS_application", "SS_component", "SS_environment", "SS_component_version", "SS_request_number"].each do |prop|
  job_params << @p.get(prop)
  @rpm.log "#{prop} => #{@p.get(prop)}"
end
version_dir = "#{baa_deploy_path}/#{@p.SS_application}/#{@p.step_version}"
@rpm.log "VERSION_DIR => #{version_dir}"
job_params << version_dir

options = {"execute_now" => execute_now }
#=> Call the job creation/execution from the framework
job_result = @transport.create_nsh_script_job(nsh_script_name, File.dirname(nsh_script_path), job_params, options)
@rpm.log job_result.inspect
pack_response "job_status", job_result["status"]
log_file_path = File.join(@p.SS_output_dir, "baa_#{job_result["job_run_id"]}.log")

