################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_BMALibraryAction_svn -----------------------#
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
# BMA Action:
#   name: Choose bma action to perform
#   type: in-list-single
#   list_pairs: snapshot,snapshot|preview,preview|install,install|testconnection,testconnection
#   position: A1:C1
# Middleware Platform:
#   name: Choose a middleware platform
#   type: in-list-single
#   list_pairs: was85,was85|was80,was80|was70,was70|portal80,portal80
#   position: E1:F1
# Server Profile Path:
#   name: enter name/path of server profile
#   type: in-text
#   position: A2:F2
# Config Package Path:
#   name: enter name/path to config package on BMA server
#   type: in-text
#   position: A3:F3
# Action Properties:
#   name: enter properties as name=value|name=/opt/${property}/other
#   type: in-text
#   position: A5:F5
# Transfer Property Prefix:
#   name: property prefix to filter properties into action (optional defaul=BMA_)
#   type: in-text
#   position: A6:B6
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

# Make sure to add methods to customer include
 
#---------------------- Variables --------------------------#

@timestamp = Time.now.strftime("%Y%m%d%H%M%S")
integration_details = @rpm.get_integration_details
environment_name = @p.get("HHSC_ENV", @p.SS_environment)
app_name = @p.get("HHSC_APP", @p.SS_application)
bma_action = @p.required("BMA Action")
bma_details(bma_action) #creates the @bma hash referred to in the shell automation erb
script_name = "bma_library_action.sh"
script_path = "#{ACTION_LIBRARY_PATH}/BMA/#{script_name}"
transfer_prefix = @p.get("Transfer Property Prefix",nil)
bma_server_profile_path = server_profile_path(@p.get("Server Profile Path"))
bma_server_profile = File.dirname(bma_server_profile_path)
bma_config_package_path = config_package_path(@p.get("Config Package_path"))
bma_config_package = File.dirname(bma_config_package_path)
bma_tokenset_name = @p.get("HHSC_BMA_TOKEN_SET", "tokens")
additional_properties = @p.get("Action Properties")
servers = {SS_integration_dns => {"os_platform" => integration_details["BMA_PLATFORM"], "CHANNEL_ROOT" => "/tmp", "dns" => "" }}

#---------------------- Main Body --------------------------#
raise "Command_Failed: No script to execute: #{script_path}" if !File.exist?(script_path)
raise "Command_Failed: No server profile" if bma_server_profile_path == ""
raise "Command_Failed: No BMA config package" if bma_config_package_path == ""
script = File.open(script_path).read

# Note RPM_CHANNEL_ROOT will be set in the run script routine
transfer_properties = {}
additional_properties.split("|").each do |item|
  pair = item.split("=")
  transfer_properties[pair[0].strip] = pair[1].strip if pair.size == 2
end

# Preprocess script body with ERB
action_txt = ERB.new(script).result(binding)
@rpm.message_box "Executing BMA - #{File.basename(script_path)}"
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

unless bma_action == "testconnection"
  # Now Move any output back to brpm
  case bma_action
    when "snapshot"
      file_path = "#{bma_snapshots_path}/snapshot_#{File.basename(bma_server_profile_path)}_#{@timestamp}.xml"
    when "install", "preview"
      file_path = "#{bma_reports_path}/#{environment_name}_#{app_name}_#{bma_action}Report_#{@timestamp}.report"
    when "drift"
      file_path = "#{bma_reports_path}/drift-#{File.basename(bma_compare_snapshot1).gsub(".xml","")}.report"
  end
  report_file = File.join(@p.SS_output_dir, File.basename(file_path))
  @rpm.log "Moving #{bma_action} output to #{report_file}"
  @transport.copy_file(File.join("//#{SS_integration_dns}", file_path), report_file)
  if ["install", "preview"].include?(bma_action)
    report_url_path = transform_xml(report_file)
    pack_response("output_report_url", "#{@p.SS_base_url}/#{report_url_path.slice(report_url_path.index("automation_results/")..255)}")
  end
  pack_response("output_report", report_file)
end

pack_response("script_file_to_execute", script_path)
pack_response("output_status", exit_status)
@p.assign_local_param("script_#{@p.SS_component}", script_path)
@p.save_local_params
params["direct_execute"] = true
