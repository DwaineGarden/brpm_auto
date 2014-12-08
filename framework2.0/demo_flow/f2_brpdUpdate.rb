#############################################################################
# Copyright @ 2012-2014 BMC Software, Inc.                                  #
# This script is supplied as a template for performing the defined actions  #
# via the BMC Release Package and Deployment. This script is written        #
# to perform in most environments but may require changes to work correctly #
# in your specific environment.                                             #
#############################################################################
#---------------------- f2_brpdUpdate -----------------------#
# Description: Updates BRPD from a deployed zip file
#  Requires: the deployed zip file path in json params as rpm_content_name

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
  echo "$*"
  exit 1
}

echo -e "\n\n\n"
echo -e "#############################################################"
echo -e "##                  BRPD Version Install                   ##"
echo -e "#############################################################"
DATE1=`date +"%m/%d/%y"`
TIME1=`date +"%H:%M:%S"`
echo "INFO: Start of Deployment execution $DATE1 $TIME1"

if [[ ! -d ${RLM_ROOT_DIR} ]]; then
  fatal "The directory $RLM_ROOT_DIR not found"
fi

RLM_PERSIST_DIR=$RLM_ROOT_DIR/persist
RELEASE_DIR=$RLM_ROOT_DIR/releases/RPD
VER_PATH=${RELEASE_DIR}/${RPM_component_version}

if [[ ! -d ${RELEASE_DIR} ]]; then
  fatal "The directory $RELEASE_DIR not found"
fi
echo "INFO: Changing to: $RELEASE_DIR"
cd $RELEASE_DIR

echo "Creating: $RPM_component_version"
if [[ -d ${VER_PATH} ]]; then
  echo "WARN: The directory $VER_PATH already exists - using"
else
  mkdir -p $VER_PATH
fi

cd $VER_PATH
zip_out=zipout_$RANDOM.txt
echo "Unzipping archive: $RPM_CONTENT_NAME"
echo "unzip -o $RPM_CHANNEL_ROOT/$RPM_CONTENT_NAME &>/tmp/$zip_out"
unzip -o $RPM_CHANNEL_ROOT/$RPM_CONTENT_NAME &>/tmp/$zip_out

sleep 20
if [[ ! -d $VER_PATH/app/config ]]; then
  sleep 20
  if [[ ! -d $VER_PATH/app/config ]]; then
    echo "Failed to extract archive properly - exiting"
    fatal
  fi
fi
echo "INFO: Setting permissions"
pwd
chmod -R 755 *
chmod -R 777 app/tmp
echo "INFO: Setting symlink for settings"
echo Current Dir: `pwd`
ls -l
cd app/config
echo "Symlink: ln -s $RLM_PERSIST_DIR/config/database.php ."
ln -s $RLM_PERSIST_DIR/config/database.php .
echo "INFO: Resetting the current link"
cd $RELEASE_DIR
unlink current
ln -s $RPM_component_version current

ls -l
echo "#-------- Full Zip Detail ---------#"
cat /tmp/$zip_out
END
#---------------------- End Ruby Shell Wrapper ----------------------------#

# Properties needed
#  RLM_ROOT_DIR, RPM_CONTENT_NAME, (intrinsic- RPM_component_version)

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
content_items = @p.required("instance_#{@p.SS_component}_content") # This is coming from the staging step
archive_zip = File.basename(content_items.first)

#---------------------- Main Body --------------------------#

#@rpm.private_password[url_parts.password] unless url_parts.password.nil?
transfer_properties = {
  "STARTSTOP_ACTION" => @p.get("Action", "stop"),
  "RLM_ROOT_DIR" => @p.SS_automation_results_dir.gsub("/automation_results",""),
  "RPM_CONTENT_NAME" => archive_zip
}
# Note RPM_CHANNEL_ROOT will be set in the run script routine
action_txt = ERB.new(script).result(binding)
@rpm.message_box "Executing BRPD Install - #{archive_zip}"
script_file = @transport.make_temp_file(action_txt)
result = @transport.execute_script(script_file)
#@rpm.log "SRUN Result: #{result.inspect}"
#pack_response("output_status", "Successfully packaged - #{File.basename(result["instance_path"])}")

params["direct_execute"] = true


