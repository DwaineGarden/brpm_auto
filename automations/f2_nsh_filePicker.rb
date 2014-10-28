#---------------------- nsh_filePicker -----------------------#
# Description: File browsing via nsh to assiged servers
#---------------------- Arguments --------------------------#
###
# server_list:
#   name: comma list of alternate servers
#   position: A1:F1
#   type: in-text
# pick a file:
#   name: file picker
#   position: A2:F2
#   type: in-external-multi-select
#   external_resource: nsh_rsc_fileBrowse
# file results:
#   name: file picker
#   position: A2:F2
#   type: out-table
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")

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

write_to "All Cool, this is the file you picked: #{params["pick a file"]}"

@p.save_local_params

