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
RELEASE_DIR=$RLM_ROOT_DIR/releases/RPD
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

