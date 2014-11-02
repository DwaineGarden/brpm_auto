################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- Action Name -----------------------#
# Description: Action Wrapper template

#---------------------- Arguments --------------------------#
###
# platform:
#   name: target server platform
#   position: A1:C1
#   type: in-list-single
#   list_pairs: linux,linux|windows,windows
# command_to_execute:
#   name: you dont typically need arguments for an action - but they are supported
#   position: A2:F2
#   type: in-text
###

#---------------------- Declarations -----------------------#
#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")

# Note action script will be processed as ERB!
#----------------- HERE IS THE ACTION SCRIPT -----------------------#
script_linux =<<-END
#!/bin/bash
echo "#------- Request $request_number in App $SS_application ---------#"
echo "Environmnent Variables"
env
<%=@p.command_to_execute %>
END

script_windows =<<-END
echo off
REM Win test script
echo "#------- Request %request_number% in App %SS_application% -----------#"
echo "Environmnent Variables"
set
<%=@p.command_to_execute %>
END

#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
# Properties will automatically be pushed to env variables if prefixed with the ARG_PREFIX
arg_prefix = "ENV_"
platform = @p.get("platform", "linux")
success = "Environment Variables"
automation_category = "Brady test_#{platform == "linux" ? "bash" : "batch"}"

#---------------------- Main Script --------------------------#
@auto.message_box "Executing Action", "title"
@auto.log "\tDirName: #{@p.required("RequiredParam1")}"
@auto.log "\tDirPath: #{@p.required("RequiredParam1")}"
@auto.log "\tSiteName: #{@p.required("RequiredParam1")}"

# This will execute the action
#  execution targets the selected servers on the step, but can be overridden in options
#  execution defaults to nsh transport, you can override with server properties (not implemented yet)
options = {} # Options can take several keys for overrides
@action = Action.new(@p,{"automation_category" => automation_category, "property_filter" => arg_prefix, "timeout" => 30, "debug" => false})
script = platform == "linux" ? script_linux : script_windows
result = @action.run!(script, options)
@auto.message_box "Results"
@auto.log @action.display_result(result)

@auto.log "Command_Failed: cannot find term: [#{success}]" unless result["stdout"].include?(success)

params["direct_execute"] = "yes"
