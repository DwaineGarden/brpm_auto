#  Shell Script to merge mulitple configs
#  4-27-15 Brady Byrd | BMC Software
#  NOTE: Should only be called for a resource -res package
#    This is called in conjunction with the virtual_hosts and server_clones 
#    topology scaling automations
BMA_DIR=<%=@bma["home_dir"] %>
LOG_LEVEL=<%=@bma["log_level"] %>
BMA_LIC=<%=@bma["license"] %>
BMA_PROP=<%=@bma["properties"] %>
BMA_OPTIONS="-properties ${BMA_PROP} -license ${BMA_LIC} -logLevel ${LOG_LEVEL}"
BMA_WORKING=<%=@bma["working_dir"] %>
APP_NAME_PREFIX=<%=bma_app_name_prefix %>
SERVER_PROF=<%=bma_server_profile %>
BMA_CONFIG_PACKAGE=<%=File.basename(bma_config_package_path) %>
STAGING_DIR=<%=@bma["staging_dir"] %>
DATE=<%=@timestamp %>

fatal() {
echo "$*"
exit 1
}

debug() {
echo "DEBUG : $*"
}

echo "#-------------------------------------------------------#"
echo "#     BMA Execution - Merge Configs"
echo "#-------------------------------------------------------#"
#new staging_dir value should be passed and made available here		
debug " Staging dir derived from RPM passed variables is ${STAGING_DIR} "
if [[ -a ${STAGING_DIR}/server_tmp/processed/${SERVER_PROF}_${APP_NAME_PREFIX}-serverModified.xml && -a ${STAGING_DIR}/vhosts_tmp/processed/${SERVER_PROF}_${APP_NAME_PREFIX}-vhostModified.xml ]]
then
	debug "Found a matching Server configuration file in: ${STAGING_DIR}/server_tmp/processed/${SERVER_PROF}_${APP_NAME_PREFIX}-serverModified.xml. This file will contain JVM configuration.  Using this configuration file"
	debug "Found a matching configuration file in: ${STAGING_DIR}/vhosts_tmp/processed/${SERVER_PROF}_${APP_NAME_PREFIX}-vhostModified.xml. This file will contain VirtualHost port assignments.  Using this configuration file"
	debug "Merging configuration for VirtualHosts and JVM Clones into the resource package"
	debug "SENDING: ${BMA_DIR}/cli/configMerge.sh -output ${STAGING_DIR}/bma_config_merged/consumed/merged_${SERVER_PROF}_${BMA_CONFIG_PACKAGE} -merge ${STAGING_DIR}/vhosts_tmp/processed/${SERVER_PROF}_${APP_NAME_PREFIX}-vhostModified.xml ${STAGING_DIR}/server_tmp/processed/${SERVER_PROF}_${APP_NAME_PREFIX}-serverModified.xml"
	${BMA_DIR}/cli/configMerge.sh -output ${STAGING_DIR}/bma_config_merged/consumed/merged_${SERVER_PROF}_${BMA_CONFIG_PACKAGE} -merge ${STAGING_DIR}/vhosts_tmp/processed/${SERVER_PROF}_${APP_NAME_PREFIX}-vhostModified.xml ${STAGING_DIR}/server_tmp/processed/${SERVER_PROF}_${APP_NAME_PREFIX}-serverModified.xml
	exitcode=$?
	if [ $exitcode -gt 0 ]
	then
		fatal "The Server Clones, VirtualHosts and Resource configuration packages could not be merged, please refer to the BMA Logs for details"
	else
		CONFIG_FILE="${STAGING_DIR}/bma_config_merged/consumed/merged_${SERVER_PROF}_${BMA_CONFIG_PACKAGE}"	
	fi

else
	debug "No VirtualHosts port configuration or Server Clones file found.  Using ClearCase refreshed resources file made available in the staging dir location"
	CONFIG_FILE="${STAGING_DIR}/${BMA_CONFIG_PACKAGE}"
fi
