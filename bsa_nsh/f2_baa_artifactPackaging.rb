#---------------------- f2_baa_artifactPackaging -----------------------#
# Description: Creates a blPackage from listed artifacts
#  Consumes properties:
#    @p.util_brpm_host_name 

#---------------------- Arguments --------------------------#
###
# package_name:
#   name: Job Path/Name this is override only (usually set via properties)
#   position: A1:F1
#   type: in-text
# staging_server:
#   name: server to pull artifacts from
#   position: A2:C2
#   type: in-text
# uploadfile_1:
#   name: File 1
#   type: in-file
#   position: A3:F3
# uploadfile_2:
#   name: File 2
#   type: in-file
#   position: A4:F4
# nsh_paths:
#   name: NSH Paths to files(comma delimited fully qualified NSH paths)
#   type: in-text
#   position: A5:F5
# creation_confirm:
#   name: output
#   type: out-text
#   position: A2:F2
###


#=== BMC Application Automation Integration Server: EC2 BSA Appserver ===#
# [integration_id=5]
SS_integration_dns = "https://ip-172-31-36-115.ec2.internal:9843"
SS_integration_username = "BLAdmin"
SS_integration_password = "-private-"
SS_integration_details = "role : BLAdmins
authentication_mode : SRP"
SS_integration_password_enc = "__SS__Cj09d1lwZDJic1ZHWmh4bVk="
#=== End ===#

#---------------------- Declarations -----------------------#
#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require "#{@p.SS_script_support_path}/baa_utilities"
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
rpm_load_module("nsh", "baa")

#---------------------- Methods ----------------------------#
# Assign local variables to properties and script arguments


#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
#=> ------------- IMPORTANT ------------------- <=#
#- the package_id comes from the JSON params set in packaging step
#-  if this is defined in a previous request and passed in JSON, we don't need to package
baa_package_id = @p.get("package_id_#{@p.SS_component}")

baa_config = YAML.load(SS_integration_details)
property_name = "BAA_BASE_PATH"
base_path = @p.get(property_name, "/mnt/deploy") #base path for pulling artifacts
properties = {}
@params.select{|l,v| l.start_with?("BAA_") }.each{|k,v| properties[k] = @p.get(k) }

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion
if baa_package_id != ""
  @rpm.message_box "Using existing BlPackage: #{baa_package_id}", "title"
  exit(0)
else
  @rpm.message_box "Creating BlPackage", "title"
end

# During packaging, the source path is abstracted in path_from_nsh_path where the property_name value is substituted for the path
#  like this ??BAA_BASE_PATH??/build/item
#=> Initialize framework objects
@baa = BAA.new(SS_integration_dns, SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc),baa_config["role"],@params)
@srun = DispatchBAA.new(@baa, @params)
#=> Build the artifact List
files_to_deploy = @srun.get_artifact_paths(@p, {})
#=> Stage, then package artifacts
result = @srun.package_artifacts(item_name, group_path, files_to_deploy, {"staging_server" => staging_server, "properties" => properties})
raise "Command_Failed: #{result[package_id]}" if result["status"].start_with?("ERROR")
package_id = result["package_id"]
@rpm.log "Package created successfully: #{result.inspect}"

#=> IMPORTANT - here is where we store the package_id for the other steps
@p.assign_local_param("package_id_#{@p.SS_component}", package_id)
@p.assign_local_param("group_path_#{@p.SS_component}", group_path)
@p.save_local_params

pack_response "creation_confirm", "Success: created package: #{item_name} in #{group_path}"


params["direct_execute"] = true #Set for local execution

