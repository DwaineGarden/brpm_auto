#---------------------- f2_nshFileBrowse -----------------------#
# Description: Uses nsh to browse and pick files on remote servers
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
#
# Description: File browsing via nsh to assiged servers
#---------------------- Arguments --------------------------#
###
# pick a file:
#   name: file picker
#   position: A1:F1
#   type: in-external-multi-select
#   external_resource: f2_rsc_nshFileBrowse
# file results:
#   name: file picker
#   position: A2:F2
#   type: out-table
###

#---------------------- Declarations -----------------------#
#=== BMC Application Automation Integration Server: EC2 BSA Appserver ===#
# [integration_id=5]
SS_integration_dns = "https://ip-172-31-36-115.ec2.internal:9843"
SS_integration_username = "BLAdmin"
SS_integration_password = "-private-"
SS_integration_details = "role : BLAdmins
authentication_mode : SRP"
SS_integration_password_enc = "__SS__Cj09d1lwZDJic1ZHWmh4bVk="
#=== End ===#
require "#{FRAMEWORK_DIR}/brpm_framework"
@baa.set_credential(SS_integration_dns, SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc), get_integration_details("role")) if @p.get("SS_transport", "ss_transport") == "baa"

#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
table_data = [["#","File", "Path"]]
per_page=10

#---------------------- Methods ----------------------------#

#---------------------- Main Routine ----------------------------#
@p.assign_local_param("selected_files", @p.get("pick a file"))
params["pick a file"].split(",").each_with_index do |item, idx|
  table_data << [idx, item.split("|")[0], item.split("|")[1]]
end
total_items = table_data.size

pack_response("file results", {:totalItems => total_items, :perPage => per_page, :data => table_data })

@rpm.log "Selected Files: #{params["pick a file"]}"

@p.save_local_params

params["direct_execute"] = true