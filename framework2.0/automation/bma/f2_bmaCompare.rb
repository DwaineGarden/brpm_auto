################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_bmaSnapshotCompare -----------------------#
# Description: Executes a shell script on target_servers
# Shell script is taken from an external library of scripts
# Make sure the property ACTION_LIBRARY_PATH is defined
# Uses shebang info from script for execution like this:
#  #![.py]/usr/bin/python %% 
# Executes on ALL Servers selected for step
#  copies all the standard properties and prefixed properties(ENV_) to environment variables
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
#
#---------------------- Arguments --------------------------#
###
# Snapshot 1:
#   name: Select the first snapshot
#   position: A1:F1
#   type: in-external-multi-select
#   external_resource: f2_rsc_nshIntegrationFileBrowse
# Snapshot 2:
#   name: Select the second snapshot
#   position: A2:F2
#   type: in-external-multi-select
#   external_resource: f2_rsc_nshIntegrationFileBrowse
# Token Set:
#   name: a token set to
#   type: in-text
#   position: A3:F3
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
# output_report:
#   name: status
#   type: out-file
#   position: A2:F2
# output_report_url:
#   name: status
#   type: out-url
#   position: A3:F3
###

#---------------------- Declarations -----------------------#
require 'erb'
require 'nokogiri'

#=== General Integration Server: BMA Sandbox ===#
# [integration_id=10100]
SS_integration_dns = "lwtd014.hhscie.txaccess.net"
SS_integration_username = "bmaadmin"
SS_integration_password = "-private-"
SS_integration_details = "BMA_HOME: /bmc/bma/BLAppRelease-8.5.0.a557498.gtk.linux.x86_64
BMA_LICENSE: /bmc/bma/BLAppRelease-8.5.0.a557498.gtk.linux.x86_64/TexasHealth5997ELO_ML.lic
BMA_WORKING: /bmc/bma_working
BMA_PLATFORM: Linux"
SS_integration_password_enc = "__SS__Cj00V2F0UldZaDFtWQ=="
#=== End ===#

#---------------------- Methods ----------------------------#

# Make sure to add bma methods to customer include  
#---------------------- Variables --------------------------#
bma_action = "drift"
@timestamp = Time.now.strftime("%Y%m%d%H%M%S")
script_name = "bma_drift_action.sh"
script_path = "#{ACTION_LIBRARY_PATH}/BMA/#{script_name}"
integration_details = @rpm.get_integration_details
bma_details(bma_action)
transfer_prefix = @p.get("Transfer Property Prefix",nil)
bma_snapshots_path = "#{@bma("working_dir")}/snapshots"
bma_archive_path = "#{@bma("working_dir")}/archive"
bma_reports_path = "#{@bma("working_dir")}/reports"
bma_tokenset_name = @p.get("Token Set")
additional_properties = @p.get("Action Properties")
servers = {SS_integration_dns => {"os_platform" => integration_details["BMA_PLATFORM"], "CHANNEL_ROOT" => "/tmp", "dns" => "" }}
bma_properties_path = "#{@bma("properties")}_#{@p.get("BMA_MIDDLEWARE_PLATFORM", "was85")}.properties"
bma_snapshot1 = @p.required("Snapshot 1").split("|")
bma_snapshot2 = @p.required("Snapshot 2").split("|")
bma_compare_snapshot1 = File.join(bma_snapshot1[1], bma_snapshot1[0]).gsub("//#{SS_integration_dns}","")
bma_compare_snapshot2 = File.join(bma_snapshot2[1], bma_snapshot2[0]).gsub("//#{SS_integration_dns}","")


#---------------------- Main Body --------------------------#
raise "Command_Failed: No script to execute: #{script_path}" if !File.exist?(script_path)
script = File.open(script_path).read

# Note RPM_CHANNEL_ROOT will be set in the run script routine
transfer_properties = {}
additional_properties.split("|").each do |item|
  pair = item.split("=")
  transfer_properties[pair[0].strip] = pair[1].strip if pair.size == 2
end

# Preprocess script body with ERB
action_txt = ERB.new(script).result(binding)
@rpm.message_box "Executing BMA Compare - #{File.basename(script_path)}"
@rpm.log "Snapshot1: #{bma_compare_snapshot1}"
@rpm.log "Snapshot2: #{bma_compare_snapshot2}"
@rpm.log "BMA Server: #{SS_integration_dns}"
script_file = @transport.make_temp_file(action_txt)
result = @transport.execute_script_per_server(script_file, {"servers" => servers, "transfer_properties" => transfer_properties, "transfer_prefix" => transfer_prefix, "strip_prefix" => false })
#@rpm.log "SRUN Result: #{result.inspect}"
exit_status = "Success"
result.split("\n").each do |line|
  if line.start_with?("EXIT_CODE:")
    raise "ERROR - EXITCODE Failure: #{line}" if line.gsub(/EXIT_CODE:\s/,"").strip.chomp.to_i != 0
  end
end

file_path = "#{bma_reports_path}/drift-#{File.basename(bma_compare_snapshot2).gsub(".xml","")}.report"
report_file = File.join(@p.SS_output_dir, File.basename(file_path))
@rpm.log "Moving #{bma_action} output to #{report_file}"
@transport.copy_file(File.join("//#{SS_integration_dns}", file_path), report_file)
pack_response("output_report", report_file)
report_url_path = transform_xml(report_file)
pack_response("output_report_url", "#{@p.SS_base_url}/#{report_url_path.slice(report_url_path.index("automation_results/")..255)}")

pack_response("script_file_to_execute", script_path)
pack_response("output_status", exit_status)
@p.assign_local_param("script_#{@p.SS_component}", script_path)
@p.save_local_params
params["direct_execute"] = true
