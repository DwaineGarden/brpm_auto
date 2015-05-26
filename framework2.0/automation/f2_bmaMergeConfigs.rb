#------------ f2_bmaMergeConfigs -----------------#
# Method to take a list of config fragments and merge
#  them into a single xml for preview/deployment
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
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
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

# Remember to add methods to customer include  
#---------------------- Variables --------------------------#
integration_details = @rpm.get_integration_details
environment_name = @p.get("HHSC_ENV", @p.SS_environment)
app_name = @p.get("HHSC_APP", @p.SS_application)
bma_action = "merge"
@timestamp = Time.now.strftime("%Y%m%d%H%M%S")
bma_details(bma_action) #creates the @bma hash referred to in the shell automation erb
script_name = "bma_merge_action.sh"
script_path = "#{ACTION_LIBRARY_PATH}/BMA/#{script_name}"
integration_details = @rpm.get_integration_details
transfer_prefix = @p.get("Transfer Property Prefix",nil)
bma_tokenset_name = @p.get("Token Set")
additional_properties = @p.get("Action Properties")
servers = {SS_integration_dns => {"os_platform" => integration_details["BMA_PLATFORM"], "CHANNEL_ROOT" => "/tmp", "dns" => "" }}
bma_server_profile_path = server_profile_path(@p.get("Server Profile Path"))
bma_server_profile = File.dirname(bma_server_profile_path)
bma_config_package_path = config_package_path(@p.get("Config Package_path"))
bma_config_package = File.dirname(bma_config_package_path)
bma_app_name_prefix = app_name # Leave option to abstract from app name
bma_staging_dir = File.dirname(bma_config_package_path)

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
@rpm.message_box "Executing BMA Merge"
@rpm.log "ServerProfile: #{bma_server_profile_path}"
@rpm.log "Configuration: #{bma_config_package_path}"
@rpm.log "BMA Server: #{SS_integration_dns}"
script_file = @transport.make_temp_file(action_txt)
result = @transport.execute_script_per_server(script_file, {"servers" => servers, "transfer_properties" => transfer_properties, "transfer_prefix" => transfer_prefix, "strip_prefix" => false })
#@rpm.log "SRUN Result: #{result.inspect}"
exit_status = "Success"
result.split("\n").each do |line|
  if line.start_with?("EXIT_CODE:")
    exit_status = "Failure"
    raise "ERROR - EXITCODE Failure: #{line}" if line.gsub(/EXIT_CODE:\s/,"").strip.chomp.to_i != 0
  end
end

pack_response("output_status", exit_status)
@p.assign_local_param("script_#{@p.SS_component}", script_path)
@p.save_local_params
params["direct_execute"] = true
