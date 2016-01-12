################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- util_f2_installModule -----------------------#
# Description: Installs automations into BRPM
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
require "#{FRAMEWORK_DIR}/brpm_framework.rb"
#
#---------------------- Arguments --------------------------#
###
# Select Modules:
#   name: Module picker
#   position: A1:F1
#   type: in-external-multi-select
#   external_resource: util_f2_rsc_moduleTree
# Force Update:
#   name: update content if automation already exists
#   type: in-list-single
#   position: A2:B2
#   list_pairs: no,no|yes,yes
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
###

#---------------------- Declarations -----------------------#

#---------------------- Methods ----------------------------#
def file_content(path)
  cont = ""
  File.open(path) do |fil|
    cont = fil.read
  end
  cont
end

def automation_type(script_content)
  a_type = @p.get("step_params") == "" ? "Automation" : "Local Ruby"
  a_type = "ResourceAutomation" if script_content.match(/def\sexecute\(/)
  a_type
end


def automation_from_file(script_path)
  new_script = true
  body = file_content(script_path)
  script_name = File.basename(script_path).gsub(".rb", "")
  if @installed_scripts.keys.include?(script_name)
    return unless @force_update == "yes"
    @rpm.log = "\tExists - updating"
    new_script = false
  end
  if new_script
    d_match = body.match(/\#\sDescription:\s.*/)
    description = d_match.nil? ? "imported f2 module" : d_match.to_s.gsub("# Description: ", "").chomp
    rest_params = {"name" => script_name, "description" => description, "content" => body, "automation_category" => @automation_category, "automation_type" => @automation_type}
    if script_name.include?("_rsc")
      rest_params["automation_type"] = "ResourceAutomation"
      rest_params["unique_identifier"] = script_name
      render_at = "list"
      d_match = body.match(/\{\s?\"render_as\"\s\=\>.*\}/)
      rest_params["render_as"] = d_match.nil? ? "List" : eval(d_match.to_s)["render_as"]
    end
    result = @rest.create("scripts", {"script" => rest_params})
  else #Update Existing
    rest_params = {"content" => body}
    result = @rest.update("scripts", @installed_scripts[script_name], {"script" => rest_params})
  end
  if result["status"].start_with?("ERROR")
    write_to result 
    raise "Error Creating Script"
  end
  cur_id = result["data"]["id"]
  result = @rest.update("scripts", cur_id, {"script" => {"aasm_state" => "pending"}})
  sleep 3
  result = @rest.update("scripts", cur_id, {"script" => {"aasm_state" => "released"}})
end

#---------------------- Variables --------------------------#
params["direct_execute"] = true
# like this: Select Modules: 'f2_getRequestInputs_basic.rb|/,package_and_delivery|/,remote_execution|/'
selected_modules = @p.get("Select Modules")
@modules_base_path = File.join(FRAMEWORK_DIR,"..","automation")
@automation_type = "Automation"
@automation_category = "Framework"
@force_update = @p.get("Force Update", "no")
@installed_scripts = {}

#---------------------- Main Body --------------------------#
if selected_modules.include?("|")
  modules_to_install = []
  selected_modules.split(",").each do |item|
    selected_module = File.join(item.split("|")[1], item.split("|")[0])
    selected_module = File.join(@modules_base_path, selected_module) unless selected_module.include?(@modules_base_path)
    modules_to_install << selected_module
  end
end
raise "Command_Failed: No script to execute: #{selected_modules}" if selected_modules == ""
@rpm.message_box "Installing Modules"
result = @rest.get("scripts", nil, {"suppress_errors" => true})
if result["status"].start_with?("ERROR")
  write_to "ERROR: unable to add automation content (no admin token)"
  exit(0)
end
result["data"].each{|l| @installed_scripts[l["name"]] = l["id"] }


# Resource Automation First
modules_to_install.each do |module_path|
  update = false
  next unless File.file?(module_path)
  next unless module_path.include?("_rsc")
  msg = "Adding Resource: #{module_path}"
  @rpm.log msg
  automation_from_file(module_path) 
end
# Then main automation
modules_to_install.each do |module_path|
  next unless File.file?(module_path)
  next if module_path.include?("_rsc")
  @rpm.log "Adding: #{module_path}"
  automation_from_file(module_path) 
end
# Do the same for Folders
modules_to_install.each do |module_path|
  next if File.file?(module_path)
  @rpm.log "#=> Module: #{File.basename(module_path)}"
  Dir.entries(module_path).reject{|k| k.start_with?(".")}.each do |script|
    automation_from_file(File.join(module_path, script)) if script.include?("_rsc")
    @rpm.log "Adding Resource: #{module_path}"
  end
  Dir.entries(module_path).reject{|k| k.start_with?(".")}.each do |script|
    automation_from_file(File.join(module_path, script)) if !script.include?("_rsc")
    @rpm.log "Adding: #{module_path}"
  end
end
  
exit_status = "Success"
pack_response("output_status", exit_status)




