################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_scriptExecute -----------------------#
# Description: Executes a shell script on target_servers
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
# Upload Action File:
#   name: script_file 1
#   type: in-file
#   position: A1:F1
# nsh_path:
#   name: NSH Path to script_file (fully qualified NSH path)
#   type: in-text
#   position: A2:F2
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
script_path = @p.get("Upload Action File")
script_path = @p.get(nsh_path, script_path)

#---------------------- Main Body --------------------------#
raise "Command_Failed: No script to execute: #{script_path}" if script_path == "" || !File.exist?(script_path)
script = File.open(script_path).read
# Note RPM_CHANNEL_ROOT will be set in the run script routine

# Preprocess script body with ERB
action_txt = ERB.new(script).result(binding)
@rpm.message_box "Executing LibraryAction - #{File.basename(script_path)}"
script_file = @transport.make_temp_file(action_txt)
result = @transport.execute_script(script_file, {"transfer_properties" => transfer_properties, "transfer_prefix" => transfer_prefix })
#@rpm.log "SRUN Result: #{result.inspect}"
exit_status = "Success"
result.split("\n").each{|line| exit_status = line if line.start_with?("EXIT_CODE:") }
pack_response("script_file_to_execute", script_path)
pack_response("output_status", exit_status)
@p.assign_local_param("script_#{@p.SS_component}", script_path)
@p.save_local_params
params["direct_execute"] = true


