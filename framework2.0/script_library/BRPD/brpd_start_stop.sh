#!/bin/sh
#
# Action to start/stop BRPD
#
# REQUIRED VARIABLES
#  RPM_CHANNEL_ROOT
#  RLM_ROOT_DIR

# Create Environment Variables
<% transfer_properties.each do |key, val| %>
<%= key + '="' + val + '"' %>
<% end %>

fatal() {
  echo "$*"
  exit 1
}

echo -e "\n\n\n"
echo -e "#############################################################"
echo -e "##                  BRPD $STARTSTOP_ACTION                           ##"
echo -e "#############################################################"
DATE1=`date +"%m/%d/%y"`
TIME1=`date +"%H:%M:%S"`
echo "INFO: Start of Deployment execution $DATE1 $TIME1"
$RLM_ROOT_DIR/bin/brlmapache $STARTSTOP_ACTION


echo -e "##############################################################\n\n\n"

