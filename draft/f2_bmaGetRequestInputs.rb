# Description: Set request input Deployment
#  Instructions: Modify this automation for each flavor of application deployment
#    add any arguments you want to be available to other steps here by prefixing them with "ARG_"
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
#---------------------- f2_bmaGetRequestInputs -----------------------#
# Description: Enter Request inputs for component deploy and promotion
# Author(s): 2015 Brady Byrd
#---------------------- Arguments --------------------------#
###
# Change Ticket ID:
#   name: Change ticket id (UAT and PROD only)
#   type: in-text
#   position: A3:C3
#   required: no
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution

#---------------------- Methods ----------------------------#
# Assign local variables to properties and script arguments

#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
ARG_PREFIX = "HHSC_"
@req = BrpmRequest.new((@p.request_id.to_i - 1000).to_s, @params["SS_base_url"], @params)
#@auto.log @req.request.inspect
component = @p.SS_component
environment_type = @p.request_environment_type
environments = @req.app_environments
components = @req.app_components
component_list = components.reject{|l| ["general","[default]"].include?(l["name"].downcase) }.map{|l| l["name"] }
@p.assign_local_param("environments", environments)
@p.assign_local_param("components", components)
@p.assign_local_param("Packaging_Environment_Types", ["Development", "Integration"])

#---------------------- Main Body --------------------------#
# Set a property in General for each component to deploy 
props = "name, value, component, global\n" 
component_list.each_with_index do |comp|
  val = components_to_deploy.include?(comp.downcase) ? "yes" : "no"
  props += "tmp_deploy_#{comp.strip},#{val}, General, true\n" 
  @p.assign_local_param("tmp_deploy_#{comp.strip}", val)
end  
set_property_flag(props)

# Transfer any flagged properties with prefix to the json params
@params.each.select{|k,v| k.start_with?(ARG_PREFIX) }.each do |k,v|
  @p.assign_local_param(k, v)
end

@p.save_local_params # Cleanup and save


