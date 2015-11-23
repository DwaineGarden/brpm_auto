################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_nsh_serverStatus -----------------------#
# Description: Performs an agent info on each of the listed servers (either step reference or passed as argument)
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 

#---------------------- Arguments --------------------------#
###
# Server List:
#   name: comma separated servers
#   position: A1:F1
#   type: in-text
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
require "#{FRAMEWORK_DIR}/brpm_framework"

#---------------------- Main Body --------------------------#
@rpm.message_box "Server Agent Status"
servers = @rpm.get_server_list
server_list = @p.get("Server List")
servers = server_list.split(",") if server_list != ""
success = "Agent Release"
result = @nsh.status(@transport.server_dns_name(servers))
result.each{|k,v| @rpm.log("#----------------#\n#{k} => #{v}") }

# Apply success or failure criteria
if result.inspect.include?(success)
  @rpm.log "Success - found term: #{success}\n"
else
  @rpm.log "Command_Failed - term not found: [#{success}]\n"
end
