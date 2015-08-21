################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_executeLibraryAction_git -----------------------#
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
# Update Action Library:
#   name: yes/no update the script library
#   type: in-list-single
#   list_pairs: no,no|yes,yes
#   position: A1:B1
# Update Status:
#   name: updated status
#   type: in-external-single-select
#   external_resource: f2_rsc_updateScriptLib_svn
#   position: D1:F1
# Select Library Action:
#   name: script file picker
#   position: A2:F2
#   type: in-external-single-select
#   external_resource: f2_rsc_libraryScriptTree
# Upload Action File:
#   name: Action file
#   type: in-file
#   position: A3:F3
# Transfer Property Prefix:
#   name: property prefix to filter properties into action
#   type: in-text
#   position: A4:B4
# Action Properties:
#   name: enter properties as name=value|name=/opt/${property}/other
#   type: in-text
#   position: A5:F5
# action_file_to_execute:
#   name: file picker
#   position: A2:F2
#   type: out-text
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
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
@baa.set_credential(SS_integration_dns, SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc), get_integration_details("role")) if @p.get("SS_transport", "ss_transport") == "baa"

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
script_path = @p.get("Upload Action File")
script_path = @p.get("Select Library Action") if script_path == ""
transfer_prefix = @p.get("Transfer Property Prefix")
additional_properties = @p.get("Action Properties")
servers = @rpm.get_server_list

#---------------------- Main Body --------------------------#
if script_path.include?("|")
  script_path = File.join(script_path.split("|")[1], script_path.split("|")[0])
  script_path = File.join(ACTION_LIBRARY_PATH, script_path) unless script_path.include?(ACTION_LIBRARY_PATH)
end
raise "Command_Failed: No script to execute: #{script_path}" if script_path == "" || !File.exist?(script_path)
script = File.open(script_path).read
# Note RPM_CHANNEL_ROOT will be set in the run script routine
transfer_properties = {}
additional_properties.split("|").each do |item|
  pair = item.split("=")
  transfer_properties[pair[0].strip] = pair[1].strip if pair.size == 2
end
# Preprocess script body with ERB
action_txt = ERB.new(script).result(binding)
@rpm.message_box "Executing LibraryAction - #{File.basename(script_path)}"
script_file = @transport.make_temp_file(action_txt)
result = @transport.execute_script_per_server(script_file, {"transfer_properties" => transfer_properties, "transfer_prefix" => transfer_prefix, "strip_prefix" => false })
#@rpm.log "SRUN Result: #{result.inspect}"
exit_status = "Success"
result.split("\n").each do |line|
  if line.start_with?("EXIT_CODE:")
    raise "ERROR - EXITCODE Failure: #{line}" if line.gsub(/EXIT_CODE:\s/,"").strip.chomp.to_i != 0
  end
end

pack_response("script_file_to_execute", script_path)
pack_response("output_status", exit_status)
@p.assign_local_param("script_#{@p.SS_component}", script_path)
@p.save_local_params
params["direct_execute"] = true


