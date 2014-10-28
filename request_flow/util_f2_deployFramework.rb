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
result = run_command(params,"cd #{persist_dir} && rm -rf brpm_framework.rb lib", "") if Dir.entries(persist_dir).include?("brpm_framework.rb")
result = run_command(params,"cd #{persist_dir} && unzip #{framework_zip}", "")

write_to "To invoke the framework, put this line in all your automations:"
if @params["path_to_persist"].length > 0
  write_to "require #{persist_dir}/brpm_framework.rb"
else
  write_to "require @params[\"SS_automation_results_dir\"].gsub(\"automation_results\",\"persist/automation_lib/brpm_framework.rb\")"
end

