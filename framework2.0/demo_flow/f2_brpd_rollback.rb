#############################################################################
# Copyright @ 2012-2014 BMC Software, Inc.                                  #
# This script is supplied as a template for performing the defined actions  #
# via the BMC Release Package and Deployment. This script is written        #
# to perform in most environments but may require changes to work correctly #
# in your specific environment.                                             #
#############################################################################
#---------------------- f2_brpdRollback -----------------------#
# Description: Updates BRPD from a deployed zip file
#  Requires: 

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
#!/bin/bash

# Script to update BRPD with from a zip file
#  Variables
# RPM_CHANNEL_ROOT
# RLM_ROOT_DIR
# RPM_component_version
# RPM_CONTENT_NAME

# Create Environment Variables
<% transfer_properties.each do |key, val| %>
<%= key + '="' + val + '"' %>
<% end %>

fatal() {
  echo "ERROR: $*"
  exit 1
}

echo -e "\n\n\n"
echo -e "#############################################################"
echo -e "##                  BRPD Version Install                   ##"
echo -e "#############################################################"
DATE1=`date +"%m/%d/%y"`
TIME1=`date +"%H:%M:%S"`
echo "INFO: Start of Rollback execution $DATE1 $TIME1"
echo "Rolling back to: $RPM_component_version"

if [[ ! -d ${RLM_ROOT_DIR} ]]; then
  fatal "The directory $RLM_ROOT_DIR not found"
fi

RLM_PERSIST_DIR=$RLM_ROOT_DIR/persist
RELEASE_DIR=$RLM_ROOT_DIR/releases
VER_PATH=${RELEASE_DIR}/${RPM_component_version}

if [[ ! -d ${RELEASE_DIR} ]]; then
  fatal "The directory $RELEASE_DIR not found"
fi
echo "INFO: Changing to: $RELEASE_DIR"
cd $RELEASE_DIR

cur_link=`ls -l $RELEASE_DIR/current`
IFS='->' b_split=($cur_link)
echo "Current version: $cur_link"
nextone=0
for i in ${b_split[@]}
do
    if [ "$nextone" -eq "1" ]; then
     version=${i//[[:blank:]]/}
    fi
    if [ "$i" == "" ]; then
     nextone=1
    fi
done
if [ $version == "" -o $version == "*/*" ]; then
  fatal "Cannot determine existing version: $version"
fi
echo "Unlinking current version: $version"
echo "INFO: Resetting the current link"
unlink current
ln -s $RPM_component_version current
echo "Removing release"
echo "rm -rf $RELEASE_DIR/$version"
rm -rf $RELEASE_DIR/$version
ls -l

END
#---------------------- End Ruby Shell Wrapper ----------------------------#

# Properties needed
#  RLM_ROOT_DIR, RPM_CONTENT_NAME, (intrinsic- RPM_component_version)

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
content_items = @p.required("instance_#{@p.SS_component}_content") # This is coming from the staging step


#---------------------- Main Body --------------------------#

#@rpm.private_password[url_parts.password] unless url_parts.password.nil?
transfer_properties = {
  "STARTSTOP_ACTION" => @p.get("Action", "stop"),
  "RLM_ROOT_DIR" => @p.SS_automation_results_dir.gsub("/automation_results","")
}
# Note RPM_CHANNEL_ROOT will be set in the run script routine
action_txt = ERB.new(script).result(binding)
@rpm.message_box "Executing BRPD Rollback"
script_file = @transport.make_temp_file(action_txt)
result = @transport.execute_script(script_file)
#@rpm.log "SRUN Result: #{result.inspect}"
#pack_response("output_status", "Successfully packaged - #{File.basename(result["instance_path"])}")

params["direct_execute"] = true


