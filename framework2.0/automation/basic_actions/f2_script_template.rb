#---------------------- baa_script_example -----------------------#
# Description: Base template for baa scripts
#  Consumes properties:
#    @p.property_name

#---------------------- Arguments --------------------------#
###
# argument_one:
#   name: Description of argument
#   position: A1:F1
#   type: in-text
# argument_two:
#   name: Description of argument
#   position: A2:C2
#   type: in-text
# automation_status:
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
require "#{FRAMEWORK_DIR}/brpm_framework"

#---------------------- Methods ----------------------------#
# Assign local variables to properties and script arguments


#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
#- construction of master path in BladeLogic
group_path = "/BRPM/#{@p.SS_application}/#{@p.SS_component}"
baa_config = YAML.load(SS_integration_details)
base_path = @p.get("BAA_BASE_PATH", "/mnt/deploy") #get a property from

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion
@baa = BAA.new(SS_integration_dns, SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc),baa_config["role"],{"output_file" => @p.SS_output_file})
@auto.log "Created successfully: #{"stuff"}"

#=> IMPORTANT - here is where we store the package_id for the other steps
@p.assign_local_param("group_path_#{@p.SS_component}", group_path)
@p.save_local_params

pack_response "automation_status", "Success: did something right"



