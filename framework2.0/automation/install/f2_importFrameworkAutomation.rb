#---------------------- Import Framework Automations -----------------------#
#    Imports automations from the framework directory
#
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
#---------------------- Arguments ---------------------------#
###
# Choose Automations to Import:
#   name: yes to import 
#   type: in-list-single
#   position: A1:B1
#   list_pairs: yes,yes|no,no
# Select Automations:
#   name: Environment to promote to
#   type: in-external-multi-select
#   position: A2:F2
#   external_resource: f2_rsc_frameworkImportTree
# Process Import:
#   name: yes to import 
#   type: in-list-single
#   position: A3:B3
#   list_pairs: yes,yes|no,no
# Import Results:
#   name: results of import
#   type: in-external-single-select
#   position: A4:F4
#   external_resource: f2_rsc_frameworkImport
###

#---------------------- Declarations -----------------------#

#---------------------- Variables -----------------------#
# Assign local variables to properties and script arguments

#---------------------- Methods -----------------------#

#---------------------- Main Routine -----------------------#
#
puts "this"