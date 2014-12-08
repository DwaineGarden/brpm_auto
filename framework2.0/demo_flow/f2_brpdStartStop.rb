#############################################################################
# Copyright @ 2012-2014 BMC Software, Inc.                                  #
# This script is supplied as a template for performing the defined actions  #
# via the BMC Release Package and Deployment. This script is written        #
# to perform in most environments but may require changes to work correctly #
# in your specific environment.                                             #
#############################################################################
#---------------------- f2_brpdStartStop -----------------------#
# Description: performs a start or stop on brpd 

#---------------------- Arguments --------------------------#
###
# Action:
#   name: start or stop action
#   type: in-list-single
#   position: A1:C1
#   list_pairs: start,start|stop,stop
###

#---------------------- Declarations -----------------------#
require 'erb'
#=== BMC Application Automation Integration Server: EC2 BSA Appserver ===#
# [integration_id=5]
SS_integration_dns = "https://ip-172-31-36-115.ec2.internal:9843"
SS_integration_username = "BLAdmin"
SS_integration_password = "-private-"
SS_integration_details = "role : BLAdmins
authentication_mode : SRP"
SS_integration_password_enc = "__SS__Cj09d1lwZDJic1ZHWmh4bVk="
#=== End ===#
@baa.set_credential(SS_integration_dns, SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc), get_integration_details("role")) if @p.SS_transport == "baa"

# Note action script will be processed as ERB!
#----------------- HERE IS THE ACTION SCRIPT -----------------------#
script = <<-END
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
END
#---------------------- Begin Ruby Shell Wrapper ----------------------------#

# Properties needed
#  STARTSTOP_ACTION, RLM_ROOT_DIR

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#

#---------------------- Main Body --------------------------#

#@rpm.private_password[url_parts.password] unless url_parts.password.nil?
transfer_properties = {
  "STARTSTOP_ACTION" => @p.get("Action", "stop"), 
  "RLM_ROOT_DIR" => @p.SS_automation_results_dir.gsub("/automation_results","")
}
# Note RPM_CHANNEL_ROOT will be set in the run script routine
action_txt = ERB.new(script).result(binding)
@rpm.message_box "Executing BRPD Start/Stop - #{@p.get("Action","stop")}"
script_file = @transport.make_temp_file(action_txt)
result = @transport.execute_script(script_file)
@rpm.log "SRUN Result: #{result.inspect}"
#pack_response("output_status", "Successfully packaged - #{File.basename(result["instance_path"])}")

params["direct_execute"] = true
