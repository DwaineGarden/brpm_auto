# Description: Set request input Deployment
#  Instructions: Modify this automation for each flavor of application deployment
#    add any arguments you want to be available to other steps here by prefixing them with "ARG_"
#---------------------- Utility Test -----------------------#
# Description: Enter Request inputs for promotion
# Author(s): 2014 Brady Byrd
#---------------------- Arguments --------------------------#
###
# Choose Components:
#   name: Select components for deploy
#   type: in-list-single
#   list_pairs: none,none|all,all|choose,choose
#   required: yes
#   position: A1:C1
# Components:
#   name: Choose components for deployment
#   type: in-external-single-select
#   position: A2:F2
#   external_resource: f2_rsc_chooseComponents
#   required: no
# Change Ticket ID:
#   name: Change ticket id (UAT and PROD only)
#   type: in-text
#   position: A3:C3
#   required: no
# Promotion Environment:
#   name: Promotion environment and stage
#   type: in-external-single-select
#   position: A5:F5
#   external_resource: f2_rsc_promotionEnvironments
#   required: no
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")

#---------------------- Methods ----------------------------#
# Assign local variables to properties and script arguments

#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
ARG_PREFIX = "ARG_"
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
# Figure out promotion environment
promotion_environment = @p.get("promotion_environment") # sent in rest
promotion_environment = @p.get("Pormotion Environment") if promotion_environment == "" # from script arguments
# Figure out promotion request template
@p.assign_local_param("promotion_request_template",@p.get("origin_request_template")) if @p.get("promotion_request_template") == ""
# Figure out which components to deploy - always deploy General
choose_components = @p.get("Choose Components")
if choose_components == "all"
  components_to_deploy = component_list
elsif choose_components == "none" # this picks up if it was sent via rest in the data parameter
  components_to_deploy = @p.get("components_to_deploy") 
  components_to_deploy = component_list if components_to_deploy == ""
else
  components_to_deploy = @p.get("Components").split(",").uniq if @p.get("Choose Components") == "choose"
end
  
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


