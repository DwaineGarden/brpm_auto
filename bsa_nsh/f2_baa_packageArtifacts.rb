#---------------------- brpm_packageArtifacts -----------------------#
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
# BAA_BASE_PATH:
#   name: Base path for source files (all paths relative to this)
#   type: in-text
#   position: A3:E3
#   required: yes
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
params["direct_execute"] = true #Set for local execution

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")

require "#{@p.SS_script_support_path}/baa_utilities"

#---------------------- Methods ----------------------------#
# Assign local variables to properties and script arguments


#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
#=> ------------- IMPORTANT ------------------- <=#
#- the package_id comes from the JSON params set in packaging step
#-  if this is defined in a previous request and passed in JSON, we don't need to package
baa_package_id = @p.get("package_id_#{@p.SS_component}")
#- collect the servers assigned to the step
servers = @p.servers.split(",").collect{|s| s.strip}
#- construction of master path in BladeLogic
group_path = "/BRPM/#{@p.SS_application}/#{@p.SS_component}"
#- Item_name is the same for template, package and job and based on component version
component_version = @p.get("SS_component_version")
artifact_paths = @auto.split_nsh_path(@p.step_version_artifact_url)
item_name = component_version == "" ? "#{@p.SS_component}_#{@p.request_id}_#{@timestamp}" : "#{@p.SS_component}_#{@p.request_id}_#{component_version}"
# override item name if specified
item_name = @p.get("job_name", item_name)
#=> ------------------------------------------- <=#

baa_config = YAML.load(SS_integration_details)
artifact_paths = @auto.split_nsh_path(@p.step_version_artifact_url)
staging_server = @p.get("staging_server", artifact_paths[0])
base_path = @p.get("BAA_BASE_PATH", "/mnt/deploy") #base path for pulling artifacts
property_name = "BAA_BASE_PATH"
properties =  @params.select{|l,v| l.start_with?("BAA_") }

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion
if baa_package_id != ""
  @auto.message_box "Using existing BlPackage: #{baa_package_id}", "title"
  exit(0)
else
  @auto.message_box "Creating BlPackage", "title"
end
# Build the list of files for the template
@baa = BAA.new(SS_integration_dns, SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc),baa_config["role"],{"output_file" => @p.SS_output_file})
files_to_deploy = []
files_to_deploy << @auto.get_attachment_nsh_path(@p.util_brpm_host_name, @p.uploadfile_1) if (@p.uploadfile_1 && !@p.uploadfile_1.empty?)
files_to_deploy << @auto.get_attachment_nsh_path(@p.util_brpm_host_name, @p.uploadfile_2) if (@p.uploadfile_2 && !@p.uploadfile_2.empty?)

if @p.nsh_paths != ""
  @p.nsh_paths.split(',').each do |path|
    files_to_deploy << @auto.path_from_nsh_path(path, base_path, property_name)
  end
end

# This gets paths from the VersionTag
if @p.step_version_artifact_url != ""
  artifact_paths[1].split(',').each do |path|
    files_to_deploy << @auto.path_from_nsh_path(path, base_path, property_name)
  end
end
 
@auto.log "#=> Building Package from:\n#{files_to_deploy.join(",")}\n#=> on server: #{staging_server}"
result = @baa.package_artifacts(item_name, group_path, files_to_deploy, {"staging_server" => staging_server, "properties" => properties})
raise "Command_Failed: #{result[package_id]}" if result["status"].start_with?("ERROR")
package_id = result["package_id"]
@auto.log "Package created successfully: #{result.inspect}"

#=> IMPORTANT - here is where we store the package_id for the other steps
@p.assign_local_param("package_id_#{@p.SS_component}", package_id)
@p.assign_local_param("group_path_#{@p.SS_component}", group_path)
@p.save_local_params

pack_response "creation_confirm", "Success: created package: #{item_name} in #{group_path}"



