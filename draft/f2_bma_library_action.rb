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
#   list_pairs: snapshot,snapshot|preview,preview|install,install|drift,drift|testconnection,testconnection
#   position: A1:C1
# Middleware Platform:
#   name: Choose a middleware platform
#   type: in-list-single
#   list_pairs: was85,was85|was80,was80|was70,was70|portal80,portal80
#   position: E1:F1
# Server Profile Path:
#   name: enter name of server profile
#   type: in-text
#   position: A2:F2
# Config Package Path:
#   name: enter path to config package on BMA server
#   type: in-text
#   position: A3:F3
# Install Package Path:
#   name: enter path to install package on BMA server
#   type: in-text
#   position: A4:F4
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
###

#---------------------- Declarations -----------------------#
require 'erb'
#=== General Integration: BMA Server ===#
# [integration_id=99]
SS_integration_dns = "172.1.168.133" #	vm-8289-2b1a
SS_integration_username = "BLAdmin"
SS_integration_password = "-private-"
SS_integration_details = "BMA_HOME: /opt/bmc/bma
BMA_LICENSE: /opt/bmc/BARA_perm.lic
BMA_PROPERTIES: /opt/bmc/bma_properties/setupDeliver
BMA_WORKING: /opt/bmc/bma_working
BMA_PLATFORM: Linux
BMA_SVN_PATH: /opt/svn/1.7.5/opt/CollabNet_Subversion"
SS_integration_password_enc = "__SS__Cj09d1lwZDJic1ZHWmh4bVk="
#=== End ===#

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
script_name = "bma_library_action.sh"
script_path = "#{ACTION_LIBRARY_PATH}/BMA/#{script_name}"
integration_details = @rpm.get_integration_details
transfer_prefix = @p.get("Transfer Property Prefix",nil)
bma_action = @p.required("BMA Action")
bma_middleware_platform = @p.get("BMA Middleware Platform", @p.get("BMA_MIDDLEWARE_PLATFORM", "was85"))
bma_server_profile_path = @p.get("Server Profile Path", @p.get("bma_server_profile_#{@p.SS_component}"))
bma_install_package_path = @p.get("Install Package Path", @p.get("bma_install_package_#{@p.SS_component}"))
bma_config_package_path = @p.get("Config Package Path", @p.get("bma_config_package_#{@p.SS_component}"))
bma_snapshots_path = "#{integration_details["BMA_WORKING"]}/snapshots"
bma_archive_path = "#{integration_details["BMA_WORKING"]}/archive"
bma_tokenset_name = @p.get("BMA_TOKENSET_NAME", "tokens")
bma_was_admin_user = @p.get("BMA_WAS_ADMIN_USER")
bma_was_admin_password = @p.get("BMA_WAS_ADMIN_PASSWORD")
bma_properties_path = "#{integration_details["BMA_PROPERTIES"]}_#{@p.get("BMA_MIDDLEWARE_PLATFORM", "was85")}.properties" # setupDeliver_${BMA_MW_PLATFORM}.properties
additional_properties = @p.get("Action Properties")
servers = {SS_integration_dns => {"os_platform" => integration_details["BMA_PLATFORM"], "CHANNEL_ROOT" => "/tmp", "dns" => "" }}

#---------------------- Main Body --------------------------#
raise "Command_Failed: No script to execute: #{script_path}" if !File.exist?(script_path)
raise "Command_Failed: No install package to deploy" if ["preview","install"].include?(bma_action) && bma_install_package_path == ""
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

pack_response("script_file_to_execute", script_path)
pack_response("output_status", exit_status)
@p.assign_local_param("script_#{@p.SS_component}", script_path)
@p.save_local_params
params["direct_execute"] = true


#---------------------- Methods ----------------------------#
def execute_bma(script_file, options = {})
  # get the body of the action
  bma_details = YAML.load(SS_integration_details)
  os_platform = get_option(bma_details, "BMA_PLATFORM", "nux")
  os = @transport.os_platform(os_platform)
  os_details = OS_PLATFORMS[os]
  content = File.open(script_file).read
  transfer_properties = get_option(options, "transfer_properties",{})
  keyword_items = get_keyword_items(content)
  params_filter = get_option(keyword_items, "RPM_PARAMS_FILTER")
  params_filter = get_option(options, "transfer_prefix", DEFAULT_PARAMS_FILTER)
  transfer_properties.merge!(get_transfer_properties(params_filter, strip_prefix = true))
  log "#----------- Executing Script on Remote BMA Server -----------------#"
  log "# Script: #{script_file}"
  result = "No servers to execute on"
  servers = @rpm.get_server_list
  message_box "OS Platform: #{os_details["name"]}"
  raise "No servers selected for: #{os_details["name"]}" if servers.size == 0
  log "# #{os_details["name"]} - Targets: #{servers.inspect}"
  log "# Setting Properties:"
  add_channel_properties(transfer_properties, servers, os)
  brpd_compatibility(transfer_properties)
  transfer_properties.each{|k,v| log "\t#{k} => #{v}" }
  shebang = read_shebang(os, content)
  log "Shebang: #{shebang.inspect}"
  wrapper_path = build_wrapper_script(os, shebang, transfer_properties, {"script_target" => File.basename(script_file)})
  log "# Wrapper: #{wrapper_path}"
  target_path = @nsh.nsh_path(transfer_properties["RPM_CHANNEL_ROOT"])
  log "# Copying script to target: "
  clean_line_breaks(os, script_file, content)
  result = @nsh.ncp(server_dns_names(servers), script_file, target_path)
  log result
  log "# Executing script on target via wrapper:"
  result = @nsh.script_exec(server_dns_names(servers), wrapper_path, target_path)
  log result
  result
end

def scm_command_paths(properties)
  scm_base_dir = "/opt/bmc/bma/profile" #@p.required("SVN_WorkingDir")
  properties["SCM_WORKING"] = scm_base_dir
  properties["SCM_SERVER_PROFILES_PATH"] = "#{scm_base_dir}/#{@p.SS_environment}/server_profiles"
  properties["SCM_SNAPSHOTS_PATH"] = "#{scm_base_dir}/#{@p.SS_environment}/snapshots"
  properties["SCM_REPORTS_PATH"] = "#{scm_base_dir}/#{@p.SS_environment}/reports"
  properties["SCM_CONFIG_PACKAGES_PATH"] = "#{scm_base_dir}/#{@p.SS_environment}/config_packages"
  properties["SCM_ARCHIVE_REPO_PATH"] = "/opt/bmc/svn_ears/#{@p.SS_environment}"
end

#---------------------- Variables --------------------------#
#content_items = @p.required("instance_#{@p.SS_component}_content") # This is coming from the staging step
bma_details = YAML.load(SS_integration_details)
transport = "nsh"
bma_mode = @p.get("BMA Action", "snapshot")
bma_config_package = @p.required("BMA_ConfigPackage") if ["preview", "install"].include?(bma_mode)
servers = @rpm.get_server_list
bma_sudo_user = "bmc"

#---------------------- Main Body --------------------------#
# Note - each of the bma_details are consumed in the erb of the script
if !defined?(@nsh)
  @rpm.log "Loading transport modules for: #{transport}"
  rpm_load_module("transport_#{transport}", "dispatch_#{transport}")
end
  
# These are the component properties to transfer
transfer_properties = {
  "TARGET_SERVER" => servers.keys[0]
}
transfer_properties["BMA_OS_ID"] = bma_sudo_user if defined?(bma_sudo_user)

# Abstract the location of scm checkout paths
scm_command_paths(transfer_properties)

# Note RPM_CHANNEL_ROOT will be set in the run script routine
action_txt = ERB.new(script).result(binding)
@rpm.message_box "Executing BMA Action: #{transfer_properties["BMA_MODE"]}"
script_file = @transport.make_temp_file(action_txt)
@rpm.log "BMA Script: #{script_file}"
#result = @transport.execute_script(script_file)
#@rpm.log "SRUN Result: #{result.inspect}"
#pack_response("output_status", "Successfully packaged - #{File.basename(result["instance_path"])}")

params["direct_execute"] = true
