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

#---------------------- Variables --------------------------#
script_name = "bma_library_action.sh"
script_path = "#{ACTION_LIBRARY_PATH}/WebSphere/#{script_name}"
integration_details = @rpm.get_integration_details
transfer_prefix = @p.get("Transfer Property Prefix",nil)
bma_action = @p.required("BMA Action")
bma_middleware_platform = @p.get("BMA Middleware Platform", @p.get("BMA_MIDDLEWARE_PLATFORM", "was85"))
bma_server_profile_path = "#{integration_details["BMA_WORKING"]}/serverprofiles/#{@p.SS_environment}"
bma_install_package_path = "#{integration_details["BMA_WORKING"]}/configurations/#{@p.SS_application}"
bma_config_package_path =  "#{integration_details["BMA_WORKING"]}/configurations/#{@p.SS_application}"
bma_snapshots_path = "#{integration_details["BMA_WORKING"]}/snapshots"
bma_archive_path = "#{integration_details["BMA_WORKING"]}/archive"
bma_tokenset_name = @p.get("BMA_TOKENSET_NAME", "tokens")
bma_was_admin_user = @p.get("BMA_WAS_ADMIN_USER")
bma_was_admin_password = @p.get("BMA_WAS_ADMIN_PASSWORD")
bma_properties_path = "#{integration_details["BMA_PROPERTIES"]}_#{@p.get("BMA_MIDDLEWARE_PLATFORM", "was85")}.properties" # setupDeliver_${BMA_MW_PLATFORM}.properties
additional_properties = @p.get("Action Properties")
servers = {SS_integration_dns => {"os_platform" => integration_details["BMA_PLATFORM"], "CHANNEL_ROOT" => "/tmp", "dns" => "" }}
params["direct_execute"] = true

#---------------------- Main Body --------------------------#

res = @nsh.status([SS_integration_dns])
@rpm.log "BMA Host Status \n#{res}"

@rpm.log "BMA Working"
target_dir = "//#{SS_integration_dns}/#{integration_details["BMA_WORKING"]}"
res = @nsh.ls(target_dir)
@rpm.log "#{target_dir}\n#{res.join("\n")}"

@rpm.log "BMA serverprofiles"
target_dir = "//#{SS_integration_dns}/#{bma_server_profile_path}"
res = @nsh.ls(target_dir)
@rpm.log "#{target_dir}\n#{res.join("\n")}"

@rpm.log "BMA configurations"
target_dir = "//#{SS_integration_dns}/#{bma_config_package_path}"
res = @nsh.ls(target_dir)
@rpm.log "#{target_dir}\n#{res.join("\n")}"
