################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- Action Name -----------------------#
# Description: Direct execute on the command line

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
# Properties will automatically be pushed to env variables if prefixed with the ARG_PREFIX
ARG_PREFIX = "ENV_"

#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
platform = @p.get("platform", "linux")

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

# This will execute the action
#  execution targets the selected servers on the step, but can be overridden in options
#  execution defaults to nsh transport, you can override with server properties (not implemented yet)
options = {} # Options can take several keys for overrides
script = platform == "linux" ? script_linux : script_windows
@action = Action.new(@p,{"automation_category" => "Brady test_#{platform == "linux" ? "bash" : "batch"}", "property_filter" => ARG_PREFIX, "timeout" => 30})
result = @action.run!(script, options)

params["direct_execute"] = "yes"
