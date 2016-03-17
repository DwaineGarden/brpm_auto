################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_baaJobExecute -----------------------#
# Description: Executes a Baa batch job from group path and name
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 

#---------------------- Arguments --------------------------#

###
#
# job_folder:
#   name: Job Folder
#   position: A1:F1
#   type: in-external-single-select
#   external_resource: baa_job_folders
# job_name:
#   name: Job Name
#   type: in-text
#   position: A2:F2
# target_mode:
#   name: Target Mode
#   type: in-list-single
#   list_pairs: 0,Select|1,JobDefaultTargets|2,AlternateBAAComponents|3,MappedBAAComponents|4,AlternateBAAServers|5,MapFromBRPMServers
#   position: A3:B3
# targets:
#   name: Targets
#   type: in-external-multi-select
#   external_resource: baa_job_targets
#   position: A4:F4
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

#=== BMC Application Automation Integration Server: DevOps_bl ===#
# [integration_id=10000]
SS_integration_dns = "https://clm-aus-003365.clm-mgmt.clm.bmc.com:9843"
SS_integration_username = "BLAdmin"
SS_integration_password = "-private-"
SS_integration_details = "role: BLAdmins
authentication_mode: SRP"
SS_integration_password_enc ="__SS__Cj09d1lwZDJic1ZHWmh4bVk="
#=== End ===#

baa_config = YAML.load(SS_integration_details)
@role = baa_config["role"]

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
require "#{params["SS_script_support_path"]}/baa_utilities"
require "#{FRAMEWORK_DIR}/brpm_framework"
options = {"baa_username" => SS_integration_username, "baa_password" => decrypt_string_with_prefix(SS_integration_password_enc), "baa_role" => @role}
rpm_load_module("transport_baa")
@baa = TransportBAA.new(SS_integration_dns, params, options)

#---------------------- Variables --------------------------#
job_name = @p.required("job_name")
job_group_id = @p.get("job_folder").split('|')[0]
job_model_type = @p.get("job_folder").split('|')[2]
job_group_rest_id = @p.get("job_folder").split('|')[1]
targets = []
target_names = []


#---------------------- Methods --------------------------#
def get_target_url_prefix(target_mode)
  case target_mode
  when "4", "AlternateBAAServers"
    return "/id/SystemObject/Server/"
  when "2", "AlternateBAAComponents", "3", "MappedBAAComponents"
    return "/id/SystemObject/Component/"
  end
end

#---------------------- Main Body --------------------------#

begin
  @rpm.message_box "Executing Job: #{job_name}"
  @rpm.log "Job Folder: #{@p.get("job_folder")}"
  job = @baa.find_job_from_job_folder(job_name, job_model_type, job_group_rest_id)
  job_url = job["uri"] rescue nil
  job_db_key = job["dbKey"] rescue nil
  job_type = job["modelType"] rescue nil
  raise "Could not find job: #{job_name} inside selected job folder." if job_url.nil?

  @rpm.log("Job URL:"+job_url)

  if (job_type == "FILE_DEPLOY_JOB") || (job_type == "NSH_SCRIPT_JOB") || (job_type == "SNAPSHOT_JOB")

    if (params["target_mode"] == "2") || (params["target_mode"] == "AlternateBAAComponents") ||
      (params["target_mode"] == "3") || (params["target_mode"] == "MappedBAAComponents")
      raise "File deploy job cannot be run against components. It can run only against servers"
    end

  end


  if (params["target_mode"] == "5") || (params["target_mode"] == "MapFromBRPMServers")
    servers = nil
    servers = params["servers"].split(",").collect{|s| s.strip} if params["servers"]
    raise "No BRPM servers found to map to BAA servers" if (servers.nil? || servers.empty?)

    target_names = servers
    targets = @baa.baa_soap_map_server_names_to_rest_uri(servers)
  elsif params["targets"]
    targets = params["targets"].split(",")
    target_names = targets.collect{ |t| t.split("|")[0] }
    targets = targets.collect{ |t| "#{get_target_url_prefix(params["target_mode"])}#{t.split("|")[1]}" }
  end

  if (params["target_mode"] == "4") || (params["target_mode"] == "AlternateBAAServers") ||
    (params["target_mode"] == "5") || (params["target_mode"] == "MapFromBRPMServers")
    h = @baa.execute_job_against_servers(job_url, targets)
  elsif (params["target_mode"] == "2") || (params["target_mode"] == "AlternateBAAComponents") ||
    (params["target_mode"] == "3") || (params["target_mode"] == "MappedBAAComponents")
    h = @baa.execute_job_against_components(job_url, targets)
  elsif (params["target_mode"] == "1") || (params["target_mode"] == "JobDefaultTargets")
    h = @baa.execute_job(job_url)
  end

  raise "Could run specified job, did not get a valid response from server" if h.nil?

  execution_status = "_SUCCESSFULLY"
  execution_status = "_WITH_WARNINGS" if (h["had_warnings"] == "true")
  if (h["had_errors"] == "true")
    execution_status = "_WITH_ERRORS"
    write_to("Job Execution failed: Please check job logs for errors")
  end

  pack_response "job_status", h["status"] + execution_status

  job_run_url = h["job_run_url"]
  @rpm.log("Job Run URL: #{job_run_url}")

  job_run_id = @baa.get_job_run_id(job_run_url)
  raise "Could not fetch job_run_id" if job_run_id.nil?

  job_result_url = @baa.get_job_result_url(job_run_url)

  if job_result_url
    h = @baa.get_per_target_results(job_result_url)
    if h
      table_data = [['', 'Target Type', 'Name', 'Had Errors?', 'Had Warnings?', 'Need Reboot?', 'Exit Code']]
      target_count = 0
      h.each_pair do |k3, v3|
        v3.each_pair do |k1, v1|
          table_data << ['', k3, k1, v1['HAD_ERRORS'], v1['HAD_WARNINGS'], v1['REQUIRES_REBOOT'], v1['EXIT_CODE*']]
          target_count = target_count + 1
        end
      end
      pack_response "target_status", {:totalItems => target_count, :perPage => '10', :data => table_data }
    end
  else
    write_to("Could not fetch job_result_url, target based status not available")
  end

  job_folder_id = @baa.baa_soap_get_group_id_for_job(job_db_key)
  job_folder_path = @baa.baa_soap_get_group_qualified_path("JOB_GROUP", job_folder_id)

  results_csv = @baa.export_job_results(job_folder_path, job_name, job_run_id, job_type, target_names)
  if results_csv
    baa_job_logs = File.join(params["SS_automation_results_dir"], "baa_job_logs")
    unless File.directory?(baa_job_logs)
      Dir.mkdir(baa_job_logs, 0700)
    end

    log_file_path = File.join(baa_job_logs, "#{job_run_id}.log")
    fh = File.new(log_file_path, "w")
    fh.write(results_csv)
    fh.close

    pack_response "job_log", log_file_path
  else
    write_to("Could not fetch job results...")
  end

  results_html = @baa.export_html_job_results(session_id, job_folder_path, job_name, job_run_id, job_type, target_names)
  if results_html
    baa_job_logs = File.join(params["SS_automation_results_dir"], "baa_job_logs")
    unless File.directory?(baa_job_logs)
      Dir.mkdir(baa_job_logs, 0700)
    end

    log_file_path = File.join(baa_job_logs, "#{job_run_id}.html")
    fh = File.new(log_file_path, "w")
    fh.write(results_html)
    fh.close

    pack_response "job_log_html", log_file_path
  end

rescue Exception => e
  write_to("Operation failed: #{e.message}, Backtrace:\n#{e.backtrace.inspect}")
end




