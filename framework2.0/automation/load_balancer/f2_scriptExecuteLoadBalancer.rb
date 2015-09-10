################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_scriptExecute -----------------------#
# Description: Executes a shell script on target_servers
# Performs load balancer actions to execute on groups of targets
# Uses shebang info from script for execution like this:
#  #![.py]/usr/bin/python %% 
# Executes on ALL Servers selected for step
#  copies all the standard properties and prefixed properties(ENV_) to environment variables
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
require "#{FRAMEWORK_DIR}/brpm_framework"
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
#   type: out-table
#   position: A1:F1
###

#---------------------- Declarations -----------------------#
#=> Note - require the correct load_balancer module here
require "#{FRAMEWORK_DIR}/../automation/load_balancer/netscaler"

#=== BMC Application Automation Integration Server: EC2 BSA Appserver ===#
# [integration_id=5]
SS_integration_dns = "https://ip-172-31-36-115.ec2.internal:9843"
SS_integration_username = "BLAdmin"
SS_integration_password = "-private-"
SS_integration_details = "role: BLAdmins
authentication_mode: SRP
profile: defaultProfile"
SS_integration_password_enc = "__SS__Cj09d1lwZDJic1ZHWmh4bVk="
#=== End ===#
@baa.set_credential(SS_integration_dns, SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc), @rpm.get_integration_details("role")) if @p.get("SS_transport", @p.ss_transport) == "baa"
@nsh.set_credential(@rpm.get_integration_details("profile"), SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc)) if @p.get("SS_transport", @p.ss_transport) == "nsh"

#---------------------- Methods ----------------------------#

def result_table(other_rows = nil)
  totalItems = 1
  table_entries = [["#","Status","Information"]]
  table_entries << ["1","Error", "Insufficient Data"] if other_rows.nil?
  other_rows.each{|row| table_entries << row } unless other_rows.nil?
  per_page=10
  {:totalItems => totalItems, :perPage => per_page, :data => table_entries }
end  

#---------------------- Variables --------------------------#
script_path = @p.get("Upload Action File")
script_path = @p.get("nsh_path", script_path)
transfer_properties = {}
unless @p.get("instance_#{@p.SS_component}") == ""
  staging_info = @p.get("instance_#{@p.SS_component}")
  payload_path = @p.get("payload_path_#{@p.SS_component}")
  payload_item = staging_info["manifest"].first
  transfer_properties["RPM_PAYLOAD"] = File.join(payload_path, payload_item)
  transfer_properties["RPM_PAYLOAD_PATH"] = payload_path
end
balancer_method = "by_number"
balancer_pattern = {"num_groups" => 4}
delivery_result = []

#---------------------- Main Body --------------------------#
raise "Command_Failed: No script to execute: #{script_path}" if script_path == "" || !File.exist?(script_path)
script = File.open(script_path).read
# Note RPM_CHANNEL_ROOT will be set in the run script routine

# Preprocess script body with ERB
action_txt = ERB.new(script).result(binding)
@rpm.message_box "Executing Library Action - #{File.basename(script_path)}"
script_file = @transport.make_temp_file(action_txt)
@rpm.log "#=> Load Balancer Delivery"
@rpm.log "Initial Servers:\n#{get_server_list.keys.join(",")}"
@rpm.log "Using #{balancer_method} by #{balancer_pattern.inspect}"

lb = LoadBalancerDelivery.new(servers,balancer_method,balancer_pattern, NetScaler, "netscaler_control") 
lb.load_balancer_grouping do |cur_targets|
  @rpm.log "Current LB Group: #{cur_targets.join(",")}"
  result = @transport.execute_script(script_file, {"transfer_properties" => transfer_properties, "servers" => cur_targets})
  exit_status = "Success"
  result.split("\n").each{|line| exit_status = line if line.start_with?("EXIT_CODE:") }
  delivery_result << [exit_status,result]
end
output_table = []
delivery_result.each_with_index do |item, idx|
  output_table << ["Group_#{idx}",item[0]]
end
pack_response("output_status", result_table(output_table))
@p.assign_local_param("script_#{@p.SS_component}", script_path)
@p.save_local_params
params["direct_execute"] = true


