#############################################################################
# Copyright @ 2012-2014 BMC Software, Inc.                                  #
# This script is supplied as a template for performing the defined actions  #
# via the BMC Release Package and Deployment. This script is written        #
# to perform in most environments but may require changes to work correctly #
# in your specific environment.                                             #
#############################################################################
#---------------------- Websphere Managed AppStart -----------------------#
# Description: Installs an App in a WAS8 cluster or server
#---------------------- Arguments --------------------------#
###
# WAS_APPLICATION:
#   name: WAS Application name
#   position: A1:E1
#   type: in-text
###

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")

# Note: automation category suffix must be in the ACTION_PLATFORMS definition in the customer_include.rb file
automation_category = "Websphere_bash"
#automation_category = "Websphere_windows"

# Note action script will be processed as ERB!
#----------------- HERE IS THE ACTION SCRIPT -----------------------#
script =<<-END

# Start application on server or cluster, used when connecting to a Deployment Manager or NodeAgent

# Jython script below is passed to the wsadmin command from line 1
#
# Requires the following variables to be set
#    WAS_APPLICATION                       ***Defaults to RPM Component
#    WAS_ADMIN_HOME
#    WAS_CLUSTER_NAME or WAS_SERVER_NAME   ***Defaults to cluster if both are set
#    WAS_NODE_NAME                         ***if deploying to a server only
#    WAS_ADMIN_USER
#    WAS_ADMIN_PASSWORD

# Content to deploy is expected to be at $VL_CHANNEL_ROOT

import os

was_server_name="null"
try:
    was_cluster_name = os.environ["WAS_CLUSTER_NAME"]
except:
    was_server_name = os.environ["WAS_SERVER_NAME"]
    was_node_name = os.environ["WAS_NODE_NAME"]
    was_cluster_name="null"

#vl_content_path = os.environ["VL_CONTENT_PATH"]
#vl_content_name = os.environ["VL_CONTENT_NAME"]
#vl_channel_root = os.environ["VL_CHANNEL_ROOT"]
application_name = os.environ["WAS_APPLICATION_NAME"]

if (was_cluster_name == "null"):
    installType="server"
    installTarget=was_server_name
else:
    installType="cluster"
    installTarget=was_cluster_name

print "Starting " + application_name + " on " + installType + " " + installTarget

if (installType == "server"):
    target = "[-node " + was_node_name + " -" + installType + " " + installTarget + "]"
else:
    target = "[-" + installType + " " + installTarget + "]"

print "target = " + target

# start application
if (installType == "server"):
    AdminApplication.startApplicationOnSingleServer(application_name, was_node_name, installTarget)
else:
    AdminApplication.startApplicationOnCluster(application_name, installTarget)

print "done"
print "Application " + application_name + " is started"

sys.exit()


END

bash_wrapper = "#{@p.get("WAS_ADMIN_HOME")}/bin/wsadmin.sh -user #{@p.get("WAS_ADMIN_USER")} -password #{@p.get("WAS_ADMIN_PASSWORD")} -lang jython -f %%"
win_wrapper = "#{@p.get("WAS_ADMIN_HOME")}\\bin\\wsadmin.bat -user #{@p.get("WAS_ADMIN_USER")} -password #{@p.get("WAS_ADMIN_PASSWORD")} -lang jython -f %%"

#---------------------- Variables ----------------------------#
# Assign local variables to properties and script arguments
# Properties will automatically be pushed to env variables if prefixed with the ARG_PREFIX
arg_prefix = "WAS_"
delimiter = automation_category.downcase.include?("_win") ? "\\" : "/"
wrapper = automation_category.downcase.include?("_win") ? win_wrapper : bash_wrapper
@p.add("path_delimiter", delimiter)
success = " is started"
timeout = @p.get("step_estimate", "300").to_i
@p.add("WAS_APPLICATION", @p.SS_component) if @p.get("WAS_APPLICATION") == ""

#---------------------- Main Script --------------------------#
raise "Command_Failed: No WAS Server or Cluster specified" if @p.get("WAS_SERVER_NAME") == "" && @p.get("WAS_CLUSTER_NAME") == ""
@auto.message_box "Websphere Managed AppStart", "title"
@auto.log "\tWAS_ADMIN_HOME: #{@p.required("WAS_ADMIN_HOME")}"
@auto.log "\tWAS_CLUSTER_NAME: #{@p.get("WAS_CLUSTER_NAME")}"
@auto.log "\tWAS_SERVER_NAME: #{@p.get("WAS_SERVER_NAME")}, NODE_NAME: #{@p.get("WAS_NODE_NAME")}"
@auto.log "\tWAS_APPLICATION: #{@p.get("WAS_APPLICATION")}"
@auto.log "\tWAS_ADMIN_USER: #{@p.required("WAS_ADMIN_USER")}"
@auto.log "\tWAS_ADMIN_PASSWORD: -private-" if @p.required("WAS_ADMIN_PASSWORD")

# This will execute the action
#  execution targets the selected servers on the step, but can be overridden in options
action_options = {
  "automation_category" => automation_category, 
  "property_filter" => arg_prefix, 
  "timeout" => timeout, 
  "debug" => false, 
  "retain_property_prefix" => true
  }
@action = Action.new(@p,action_options)

# Execution defaults to nsh transport, you can override with server properties (not implemented yet)
# Options can take several keys for overrides
run_options = {
  "wrapper_script" => wrapper
  #"payload" => path_to_payload file to reference e.g. ear/war file
  } 
result = @action.run!(script, run_options)
display_result = @action.display_result(result)

@auto.log "Command_Failed: cannot find term: [#{success}]" unless display_result.include?(success)

params["direct_execute"] = "yes"
