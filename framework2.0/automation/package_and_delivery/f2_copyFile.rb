#---------------------- f2_copyFile -----------------------#
# Description: Copies a file or directory via NSH (end directories with a trailing /)
# Executes on ALL Servers selected for step
#  copies all the standard properties and prefixed properties(ENV_) to environment variables
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
require "#{FRAMEWORK_DIR}/brpm_framework.rb"
#
#---------------------- Arguments --------------------------#
###
# uploadfile_1:
#   name: File 1
#   type: in-file
#   position: A1:F1
# artifact_paths:
#   name: NSH paths to files (use trailing slash for directory)
#   type: in-text
#   position: A2:F2
# Destination Path:
#   name: Path on target
#   type: in-text
#   position: A3:F3
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = "yes"

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
servers = @rpm.get_server_list
cur_server = servers.keys.first
os = servers[cur_server]["os_platform"]
channel_root = servers[cur_server]["CHANNEL_ROOT"]
files_to_deploy = @transport.get_artifact_paths(@p, options = {})
transfer_properties = @transport.get_transfer_properties
destination_path = @p.get("Destination Path", channel_root)

#---------------------- Main Body --------------------------#
destination_path = File.join("//#{cur_server}", destination_path) unless destination_path.start_with?("//")

@rpm.message_box "Copying File", "title"
# Copy Files
files_to_deploy.each do |cur_path|
  @transport.copy_file(cur_path, destination_path)
end