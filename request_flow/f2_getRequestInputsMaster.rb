# Description: Set request input for MST Deployment
#  Instructions: Modify this automation for each flavor of application deployment
#   => Update the Packaging_Environments array in the variables section
#      These are the environment_types in which packaging is allowed 
#---------------------- Utility Test -----------------------#
# Description: Enter Request inputs for promotion
# Author(s): Brady Byrd, Scott Dunbar
#---------------------- Arguments --------------------------#
###
# Choose Tech Stacks:
#   name: Analyze Promotion Environment
#   type: in-list-single
#   list_pairs: none,none|all,all|choose,choose
#   required: yes
#   position: A1:C1
# tech_stacks:
#   name: Choose tech stacks for deployment
#   type: in-external-single-select
#   position: A2:F2
#   external_resource: rsc_chooseTechStack
#   required: no
# ARG_ServiceNow_ChangeID:
#   name: ServiceNow change ticket id (UAT and PROD only)
#   type: in-text
#   position: A3:C3
#   required: no
# Analyze Promotion:
#   name: Analyze Promotion Environment
#   type: in-list-single
#   list_pairs: no,No|yes,Yes
#   required: no
#   position: A4:C4
# ARG_Promotion_Environment:
#   name: Promotion environment and stage
#   type: in-external-single-select
#   position: A5:F5
#   external_resource: rsc_getPromotionEnvironment
#   required: no
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
if params.has_key?("include_path_ruby")
  tmp = params["include_path_ruby"]
  if File.exist?(tmp)
    require tmp
  else
    write_to("Command_Failed: cant find include file: " + tmp)
  end
else
  write_to "This script requires a property: include_path_ruby"
  #exit(1)
end

#---------------------- Methods ----------------------------#
# Assign local variables to properties and script arguments

#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
ARG_PREFIX = "CITI_"
@p.assign_local_param("Packaging_Environment_Types", ["Development", "Integration"])
tech_stacks = @p.tech_stacks
component = @p.SS_component
@params["View Server Channels"] = {}
all_tech_stacks = @p.required("RLM_TECH_STACKS")
all_tech_stacks_list = all_tech_stacks.split(",")
#environment_type = @params["request_environment_type"]
environment_type = @p.request_environment_type
promotion_environment = @p.get("ARG_Promotion_Environment").to_s

if @p.present_json?("rpd_package_instance_id")
  write_to "Running promotion - working with InstanceID: #{@p.rpd_package_instance_id}"
else
  unless @p.get("Packaging_Environment_Types").include?(environment_type)
    message_box "Command_Failed: Promotion only environment"
    write_to "\tMust have a package instance already defined"
    exit(1)
  end
end
      
#---------------------- Main Body --------------------------#
# Do your work here
begin
  if @p.get("Choose Tech Stacks") == "none" || tech_stacks.length < 1
    message_box "Command_Failed: No tech stack chosen to deploy"
    raise "No tech stack chosen to deploy"
  end
  stacks_list = tech_stacks.split(",")
  all_tech_stacks_list.each_with_index{|k,idx| stacks_list << idx} if @p.get("Choose Tech Stacks") == "all"
  
  props = "name, value, component, global\n" 
  all_tech_stacks_list.each_with_index do |item,idx|
    val = stacks_list.include?(idx.to_s) ? "yes" : "no"
    props += "tmp_tech_stack_#{item.strip},#{val}, #{@p.SS_component}, true\n" 
    @p.assign_local_param("tmp_tech_stack_#{item.strip}", val)
  end  
  set_property_flag(props)
  @p.assign_local_param("tech_stacks", all_tech_stacks) 
  
  # Set Promotion Environment
  unless @p.get("promotion_table") == ""
    @target_env = nil
    promotion_table = @p.get("promotion_table")
    promotion_environment.split(",").each do |env_id|
      ipos = promotion_table.map{|k| k[0] }.index(env_id)
      @target_env = promotion_table[ipos][1] if promotion_table[ipos][2] == "Promotion"
      @target_env = @target_env.split("-")[1].strip if promotion_table[ipos][2] == "Promotion"
    end
    if @target_env.nil?
      message_box "Command_Failed: Select a Valid promotion environment", "sep"
      raise "Invalid Promotion Environment"
    end
  end
  @params.each.reject{|k,v| !k.start_with?(ARG_PREFIX)}.each do |k,v|
  	@p.assign_local_param("ARG_#{k}", v) unless @params.has_key?("ARG_#{k}")
    @p.assign_local_param("ARG_#{k}", @p.get("#{k}_override"))  unless @p.get("#{k}_override") == ""
  end

  @params.each.reject{|k,v| !k.start_with?("ARG_")}.each do |k,v|
  	@p.assign_local_param(k.gsub("ARG_",""), v) unless @p.get(k) == ""
    write_to "Setting request_param: #{k.gsub("ARG_","")}"
    #@request_params[k.gsub("ARG_","#{component}_")] = v if !@params[k].nil? and @params[k].length > 0
  end
 
  @p.save_local_params # Cleanup and save

rescue Exception => e
  write_to("Command_Failed: #{e.message}, Backtrace:\n#{e.backtrace.inspect}")
end

