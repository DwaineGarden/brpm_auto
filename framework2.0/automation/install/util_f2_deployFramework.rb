################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- util_f2_deployFramework -----------------------#
# Description: Deploys the framework files from a zip attached to the step

#---------------------- Arguments --------------------------#
###
# Install Path:
#   name: Path to where framework should be stored (default=<RLM_ROOT>/persist)
#   position: A1:F1
#   type: in-text
# Upload Framework Zip:
#   name: Zip archive of framework
#   type: in-file
#   position: A2:F2
# Bladelogic NSH Path:
#   name: Base path to bladelogic dir
#   type: in-text
#   position: A3:D3
###

#---------------------- Declarations -----------------------#
require 'fileutils'
params["direct_execute"] = true
initial_scripts_to_add = ["basic_actions/f2_directExecute.rb", "install/util_f2_rsc_moduleTree.rb", "install/util_f2_installModule.rb"]

#---------------------- Methods ----------------------------#
def replace_line(body_array, key, val)
  ipos = nil
  body_array.each_with_index{|l,idx| ipos = idx if l.start_with?(key) }
  unless ipos.nil?
    body_array[ipos] = "#{key} = \"#{val}\""
  end
end

def file_content(path)
  cont = ""
  File.open(path) do |fil|
    cont = fil.read
  end
  cont
end

def create_automation_from_file(script_path)
  automation_category = "Framework"
  body = file_content(script_path)
  write_to "\tInstall: #{script_path}"
  script_name = File.basename(script_path).gsub(".rb", "")
  d_match = body.match(/\#\sDescription:\s.*/)
  description = d_match.nil? ? "imported f2 module" : d_match.to_s.gsub("# Description: ", "").chomp
  rest_params = {"name" => script_name, "description" => description, "content" => body, "automation_category" => automation_category, "automation_type" => "Automation"}
  if script_name.include?("_rsc")
    rest_params["automation_type"] = "ResourceAutomation"
    rest_params["unique_identifier"] = script_name
    render_at = "list"
    d_match = body.match(/\{\s?\"render_as\"\s\=\>.*\}/)
    rest_params["render_as"] = d_match.nil? ? "List" : eval(d_match.to_s)["render_as"]
  end
  result = @rest.create("scripts", {"script" => rest_params})
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
if @params["Install Path"].length > 0
  persist_dir = @params["Install Path"]
else  
  persist_dir = @params["SS_automation_results_dir"].gsub("automation_results","persist")
end
framework_zip = @params["Upload Framework Zip"]
token = params["SS_api_token"]

#---------------------- Main Body --------------------------#
# Check that framework directory exists
FileUtils.mkdir_p(persist_dir) unless File.exist?(persist_dir)
write_to "#-------------- Updating Framework ------------------#"
write_to "\t Install To: #{persist_dir}"
write_to "\t Using: #{framework_zip}"
FileUtils.cd(persist_dir, :verbose => true)
#tmp_dir = File.join(persist_dir, "fmk_tmp")
#FileUtils.mkdir_p(tmp_dir) 
FileUtils.rm_r(%w(brpm_framework.rb lib), :force => true) if Dir.entries(persist_dir).include?("brpm_framework.rb")
if Dir.entries(persist_dir).include?("customer_include.rb")
  #result = run_command(params,"cd #{persist_dir} && mv -f customer_include.rb orig_customer_include.rb", "") 
  write_to "A new customer_include_default file exists - check for important changes from new version"
end
 
FileUtils.cd(persist_dir, :verbose => true)
result = run_command(params,"unzip -o #{framework_zip}", "")
if !File.exist?(File.join(persist_dir,"customer_include.rb"))
  write_to "Creating a new customer_include.rb file in #{persist_dir}"
  write_to "You must edit the file and change the defaults to match your environment"
  FileUtils.cp File.join(persist_dir, "framework", "customer_include_default.rb"), File.join(persist_dir,"customer_include.rb")
  body = File.open(File.join(persist_dir, "framework", "customer_include_default.rb")).read
  body_lines = body.split("\n")
  replace_line(body_lines, "Token", token) if params["request_login"] == "admin"
  replace_line(body_lines, "BAA_BASE_PATH", params["Bladelogic NSH Path"]) if params["Bladelogic NSH Path"].length > 2
  replace_line(body_lines, "ACTION_LIBRARY_PATH", File.join(persist_dir,"script_library"))
  File.open(File.join(persist_dir,"customer_include.rb"),"w+") do |fil|
    fil.puts body_lines.join("\n")
  end
end
#FileUtils.cp_r(File.join(tmp_dir, "framework/."), persist_dir, :verbose => true)
write_to "\tModifying ssh_script_header"
cur_content = File.open(File.join(params["SS_script_support_path"], "ssh_script_header.rb")).read
if !cur_content.include?("Initialize RPM Framework")
  add_lines = "#=> Initialize RPM Framework\n"
  add_lines += "FRAMEWORK_DIR = \"#{File.join(persist_dir,"framework")}\"\n"
  #add_lines += "framework_addition = File.join(FRAMEWORK_DIR, \"lib\", \"ssh_script_header_additions.rb\")\n"
  #add_lines += "load framework_addition\n"
  add_lines += "#=> End RPM Framework Addition\n"
  fil = File.open(File.join(params["SS_script_support_path"], "ssh_script_header.rb"), "w+")
  fil.puts add_lines
  fil.puts cur_content #.gsub("def load_input_params", "def orig_load_input_params")
  fil.close
end
 
write_to "The framework will now be loaded for all your automations (except resource automation)."
write_to "The transport agent for the framework will load depending on the SS_transport property which can be (ssh, nsh or baa)."
write_to "In order to use the import automation capability, you will need to add 'Framework' to the automation categories list in Metadata|Lists"
write_to "Note: this has modified the default script header, you will need to rerun this automation after any RPM patch is applied"

if params["request_login"] == "admin"
  require "#{persist_dir}/framework/lib/brpm_automation"
  require "#{persist_dir}/framework/lib/rest"
  @rest = BrpmRest.new(params["SS_base_url"], params, {"token" => token})
  result = @rest.get("scripts", nil, {"suppress_errors" => true})
  if result["status"].start_with?("ERROR")
    write_to "ERROR: unable to add automation content (no admin token)"
    exit(0)
  end
  script_names = []
  result["data"].each{|l| script_names << l["name"] }
  initial_scripts_to_add.each do |script|
    next if script_names.include?(File.basename(script).gsub(".rb",""))
    script_path = File.join(persist_dir,"automation", script)
    create_automation_from_file(script_path)
  end
end
