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
# path_to_persist:
#   name: Path to where framework should be stored (default=<RLM_ROOT>/persist)
#   position: A1:F1
#   type: in-text
# upload_framework_zip:
#   name: Zip archive of framework
#   type: in-file
#   position: A2:F2
###

#---------------------- Declarations -----------------------#
require 'fileutils'
params["direct_execute"] = true

#---------------------- Main Body --------------------------#
# Check that framework directory exists
if @params["path_to_persist"].length > 0
  persist_dir = @params["path_to_persist"]
else  
  persist_dir = @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib")
end
framework_zip = @params["upload_framework_zip"]
FileUtils.mkdir_p(persist_dir) unless File.exist?(persist_dir)
write_to "#-------------- Updating Framework ------------------#"
write_to "\t Using: #{framework_zip}"
FileUtils.cd(persist_dir, :verbose => true)
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
  FileUtils.cp File.join(persist_dir,"customer_include_default.rb"), File.join(persist_dir,"customer_include.rb")
end
cur_content = File.open(File.join(params["SS_script_support_path"], "ssh_script_header.rb")).read
if !cur_content.include?("class BrpmAutomation")
  FileUtils.cd(params["SS_script_support_path"], :verbose => true)
  FileUtils.mv("ssh_script_header.rb", "ORIG_ssh_script_header.rb")
end
FileUtils.cd(params["SS_script_support_path"], :verbose => true)
FileUtils.cp(File.join(persist_dir,"lib", "ssh_script_header.rb"), "ssh_script_header.rb")
 
write_to "The framework will now be loaded for all your automations (except resource automation)."
write_to "The transport agent for the framework will load depending on the SS_transport property which can be (ssh, nsh or baa)."
write_to "Note: this has replaced the default script header, you will need to reload the framwork after any RPM patch is applied"

