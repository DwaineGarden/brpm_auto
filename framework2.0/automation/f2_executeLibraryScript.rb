################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_executeLibraryScript -----------------------#
# Description: Executes a shell script on target_servers
# Shell script is taken from an external library of scripts
# Make sure the property F2_SCRIPT_LIBRARY_ROOT is defined
# Uses shebang info from script for execution like this:
#  #![.py]/usr/bin/python %% 
# Executes on ALL Servers selected for step
#  copies all the standard properties and prefixed properties(ENV_) to environment variables
#
#---------------------- Arguments --------------------------#
###
# Update Script Library:
#   name: yes/no update the script library
#   type: in-list-single
#   list_pairs: no,no|yes,yes
#   position: A1:B1
# Update Status:
#   name: updated status
#   type: in-external-single-select
#   external_resource: f2_rsc_UpdateScriptLib
#   position: D1:F1
# Select Library Script:
#   name: script file picker
#   position: A2:F2
#   type: in-external-single-select
#   external_resource: f2_rsc_libraryScriptTree
# Upload Script File:
#   name: Script file
#   type: in-file
#   position: A3:C3
# Transfer Property Prefix:
#   name: property prefix to filter properties into script
#   type: in-text
#   position: A4:C4
# script_file_to_execute:
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
@baa.set_credential(SS_integration_dns, SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc), get_integration_details("role")) if @p.SS_transport == "baa"

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
script_path = @p.get("Upload Script File")
script_path = @p.get("Select Library Script") if script_path == ""
transfer_prefix = @p.get("Transfer Property Prefix", ARG_PREFIX)

#---------------------- Main Body --------------------------#
if script_path.include?("|")
  script_path = File.join(script_path.split("|")[1], script_path.split("|")[0])
  script_path = File.join(SCRIPT_LIBRARY_ROOT, script_path) unless script_path.include?(SCRIPT_LIBRARY_ROOT)
end
raise "Command_Failed: No script to execute: #{script_path}" if script_path == "" || !File.exist?(script_path)
script = File.open(script_path).read
# Note RPM_CHANNEL_ROOT will be set in the run script routine
transfer_properties = @params.select{|k,v| k.start_with?(transfer_prefix) }
# Preprocess script body with ERB
action_txt = ERB.new(script).result(binding)
@rpm.message_box "Executing LibraryScript - #{File.basename(script_path)}"
script_file = @transport.make_temp_file(action_txt)
result = @transport.execute_script(script_file)
@rpm.log "SRUN Result: #{result.inspect}"
pack_response("output_status", "Successfully packaged - #{File.basename(result["instance_path"])}")
pack_response("script_file_to_execute", script_path)
@p.assign_local_param("script_#{@p.SS_component}", script_path)
@p.save_local_params
params["direct_execute"] = true


