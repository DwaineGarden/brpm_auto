# Description: Execute an automation in the remote libary
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
#---------------------- f2_getRequestInputs_basic -----------------------#
# Description: Enter Request inputs for component deploy and promotion
# Author(s): 2015 Brady Byrd
#---------------------- Arguments --------------------------#
###
# Select Library Action:
#   name: script file picker
#   position: A1:F1
#   type: in-external-single-select
#   external_resource: f2_rsc_libraryScriptTree
# Input Argument1:
#   name: First input argument
#   type: in-text
#   position: A2:F2
# Input Argument2:
#   name: First second argument
#   type: in-text
#   position: A3:F3
# Input Argument3:
#   name: First third argument
#   type: in-text
#   position: A4:F4
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
require 'C:/BMC/persist/automation_libs/brpm_framework.rb'

#---------------------- Methods ----------------------------#
# Assign local variables to properties and script arguments

#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments

#---------------------- Main Body --------------------------#
# Set a property in General for each component to deploy 
execute_library_action


