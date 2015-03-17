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
# automation_library_path:
#   name: Path to where framework should be stored (default=<RLM_ROOT>/persist)
#   position: A1:F1
#   type: in-text
# upload_framework_zip:
#   name: Zip archive of framework
#   type: in-file
#   position: A2:F2
# update script library:
#   name: update available library scripts
#   type: in-list-single
#   list_pairs: yes,yes|no,no
#   position: A3:C3
###

#---------------------- Declarations -----------------------#
require 'fileutils'
params["direct_execute"] = true

#---------------------- Main Body --------------------------#
# Check that framework directory exists
if @params["automation_library_path"].length > 0
  persist_dir = @params["automation_library_path"]
else  
  persist_dir = @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib")
end
framework_zip = @params["upload_framework_zip"]
FileUtils.mkdir_p(persist_dir) unless File.exist?(persist_dir)
write_to "#-------------- Updating Framework ------------------#"
write_to "\t Using: #{framework_zip}"
FileUtils.cd(persist_dir, :verbose => true)
tmp_dir = File.join(persist_dir, "fmk_tmp")
FileUtils.mkdir_p(tmp_dir) 
FileUtils.rm_r(%w(brpm_framework.rb lib), :force => true) if Dir.entries(persist_dir).include?("brpm_framework.rb")
if Dir.entries(persist_dir).include?("customer_include.rb")
  #result = run_command(params,"cd #{persist_dir} && mv -f customer_include.rb orig_customer_include.rb", "") 
  write_to "A new customer_include_default file exists - check for important changes from new version"
end
FileUtils.cd(tmp_dir, :verbose => true)
result = run_command(params,"unzip -o #{framework_zip}", "")
if !File.exist?(File.join(persist_dir,"customer_include.rb"))
  write_to "Creating a new customer_include.rb file in #{persist_dir}"
  write_to "You must edit the file and change the defaults to match your environment"
  FileUtils.cp File.join(tmp_dir, "framework", "customer_include_default.rb"), File.join(persist_dir,"customer_include.rb")
end
FileUtils.cp_r(File.join(tmp_dir, "framework/."), persist_dir, :verbose => true)
cur_content = File.open(File.join(params["SS_script_support_path"], "ssh_script_header.rb")).read
if !cur_content.include?("Initialize RPM Framework")
  add_lines = "#=> Initialize RPM Framework\n"
  add_lines += "FRAMEWORK_DIR = \"#{persist_dir}\"\n"
  add_lines += "framework_addition = File.join(FRAMEWORK_DIR, \"lib\", \"ssh_script_header_additions.rb\")\n"
  add_lines += "load framework_addition\n"
  add_lines += "#=> End RPM Framework Addition\n"
  fil = File.open(File.join(params["SS_script_support_path"], "ssh_script_header.rb"), "w+")
  fil.puts add_lines
  fil.puts cur_content.gsub("def load_input_params", "def orig_load_input_params")
  fil.close
end
 
write_to "The framework will now be loaded for all your automations (except resource automation)."
write_to "The transport agent for the framework will load depending on the SS_transport property which can be (ssh, nsh or baa)."
write_to "In order to use the import automation capability, you will need to add 'Framework' to the automation categories list in Metadata|Lists"
write_to "Note: this has modified the default script header, you will need to rerun this automation after any RPM patch is applied"

if params["update script library"] == "yes"
  script_lib = File.join(params["SS_script_support_path"], "LIBRARY", "automation")
  FileUtils.mkdir_p(File.join(script_lib, "Framework")) unless File.exist?(File.join(script_lib, "Framework"))
  FileUtils.cp_r File.join(tmp_dir, "automation/."), File.join(script_lib, "Framework"), :verbose => true
end