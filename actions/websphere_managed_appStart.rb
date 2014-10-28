# Wrapper for Action Script

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")

# Properties will automatically be pushed to env variables if prefixed with the ARG_PREFIX
ARG_PREFIX = "ENV_"

# Note action script will be processed as ERB!
#----------------- HERE IS THE ACTION SCRIPT -----------------------#
script =<<-END
#![.py]/bin/sh -c "$WAS_HOME/bin/wsadmin.sh -user $WAS_ADMIN_USER -password $WAS_ADMIN_PASSWORD -lang jython -f %%"
#############################################################################
# Copyright @ 2012-2014 BMC Software, Inc.                                  #
# This script is supplied as a template for performing the defined actions  #
# via the BMC Release Package and Deployment. This script is written        #
# to perform in most environments but may require changes to work correctly #
# in your specific environment.                                             #
#############################################################################

# Start application on server or cluster, used when connecting to a Deployment Manager or NodeAgent

# Jython script below is passed to the wsadmin command from line 1
#
# Requires the following variables to be set
#    WAS_HOME
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

vl_content_path = os.environ["VL_CONTENT_PATH"]
vl_content_name = os.environ["VL_CONTENT_NAME"]
vl_channel_root = os.environ["VL_CHANNEL_ROOT"]


if (was_cluster_name == "null"):
    installType="server"
    installTarget=was_server_name
else:
    installType="cluster"
    installTarget=was_cluster_name

print "Starting " + vl_content_path + " on " + installType + " " + installTarget

if (installType == "server"):
    target = "[-node " + was_node_name + " -" + installType + " " + installTarget + "]"
else:
    target = "[-" + installType + " " + installTarget + "]"

path = vl_channel_root + '\\' + vl_content_path

print "target = " + target

# start application
if (installType == "server"):
    AdminApplication.startApplicationOnSingleServer(vl_content_name, was_node_name, installTarget)
else:
    AdminApplication.startApplicationOnCluster(vl_content_name, installTarget)

print "done"
print "Application " + vl_content_name + " is started"

sys.exit()


END

# This will execute the brpd action
run_brpd_action(script)
