################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_scriptExecute -----------------------#
# Description: Executes a shell script on target_servers
# Uses shebang info from script for execution like this:
#  #![.py]/usr/bin/python %% 
# Executes on ALL Servers selected for step
#
#---------------------- Arguments --------------------------#
###
# upload_script:
#   name: script_file 1
#   type: in-file
#   position: A1:F1
# script_path:
#   name: NSH Paths to script_file (fully qualified NSH paths)
#   type: in-text
#   position: A2:F2
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
require 'fileutils'

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
rpm_load_module("nsh", "dispatch_nsh")
nsh_path = defined?(NSH_PATH) ? NSH_PATH : "/opt/bmc/blade8.5/NSH"
@srun = NSHDispatcher.new(nsh_path, @params)

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
brpm_hostname = @p.SS_base_url.gsub(/^.*\:\/\//, "").gsub(/\:\d.*/, "")
script_file = @srun.get_attachment_nsh_path(brpm_hostname, @p.upload_script) unless @p.upload_script == ""
script_file = @p.get(script_path, script_file)

#---------------------- Main Body --------------------------#
# Deploy and unzip the package on all targets
raise "Command_Failed: no script to execute" if script_file.size < 3

options = {"verbose" => true}
result = @srun.execute_script(script_file, options)
pack_response("output_status", "Successfully executed - #{script_file}")
