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

