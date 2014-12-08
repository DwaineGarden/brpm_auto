#![.py]/bin/sh -c "<%=@p.get("WAS_ADMIN_HOME") %>/bin/wsadmin.sh -user <%=@p.get("WAS_ADMIN_USER") %> -password <%=@p.get("WAS_ADMIN_PASSWORD") %> -lang jython -f %%"
# WIN_WRAPPER: <%=@p.get("WAS_ADMIN_HOME") %>\\bin\\wsadmin.bat -user <%=@p.get("WAS_ADMIN_USER") %> -password <%=@p.get("WAS_ADMIN_PASSWORD") %> -lang jython -f %%
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

