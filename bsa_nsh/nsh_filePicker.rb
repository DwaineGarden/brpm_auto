#---------------------- nsh_filePicker -----------------------#
# Description: File browsing via nsh to assiged servers
#---------------------- Arguments --------------------------#
###
# pick a file:
#   name: file picker
#   position: A1:F1
#   type: in-external-multi-select
#   external_resource: nsh_rsc_fileBrowse
# file results:
#   name: file picker
#   position: A2:F2
#   type: out-table
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
include_property = "include_path_ruby"
if params.has_key?(include_property)
  tmp = params[include_property]
  if File.exist?(tmp)
    require tmp
    # Requiring the framework will set the @p (params) object, @rest and @auto objects
  else
  	write_to("Command_Failed: cant find include file: " + tmp)
  end
else
  write_to "This script requires a property: #{include_property}"
  #exit(1)
end

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

