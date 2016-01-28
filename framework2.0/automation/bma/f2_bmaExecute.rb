#############################################################################
# Copyright @ 2012-2014 BMC Software, Inc.                                  #
#   BMA General Action Script                                               #
#   BJB 1/3/2015 Adapted from                                               #
#   S Dunbar BMC @ 10/10/2014                                               #
#                                                                           #
#############################################################################
#---------------------- f2_bmaExecute -----------------------#
# Description: A shell script library to execute BMA actions on a linux host
# Uses an integration to define the BMA host and parameters, it will use the step
# servers as the target for the bma actions (server_profile)
# The step should be attached to a BMA_appserver component that has these properties:
#=> WASAdminUser, WASAdminPassword, BMATokensetName, BMAServerProfile
#=> Must be executed with NSH transport

#---------------------- Arguments ---------------------------#
###
# BMA Action:
#   name: Action for BMA to perform
#   type: in-list-single
#   position: A1:C1
#   list_pairs: testconnection,test_connection|snapshot,snapshot|preview,preview|install,install|drift,drift
# BMA_ServerProfile:
#   name: Name of server profile to use
#   type: in-text
#   position: A2:D2
# BMA_ConfigPackage:
#   name: Config Package to install/preview (optional for snapshot and test)
#   type: in-text
#   position: A3:D3
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
###
#---------------------- Declarations -----------------------#
require 'erb'

#=== General Integration Server: BMA ===#
# [integration_id=2]
SS_integration_dns = "172.16.1.134"
SS_integration_username = "BLAdmin"
SS_integration_password = "-private-"
SS_integration_details = "BMA_HOME: /opt/bmc/bma
BMA_LICENSE: /opt/bmc/BARA_perm.lic
BMA_PROPERTIES: /opt/bmc/bma_properties/setupDeliver.
BMA_WORKING: /opt/bmc/bma_working
BMA_PLATFORM: Linux"
SS_integration_password_enc = "__SS__"
#=== End ===#



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
######################## Variables
BMA_DIR="<%=bma_details["BMA_HOME"] %>"
LOG_LEVEL="ERROR"   
BMA_LIC="<%=bma_details["BMA_LICENSE"] %>"
BMA_PROP="<%=bma_details["BMA_PROPERTIES"] %>$"
BMA_OPTIONS="-properties ${BMA_PROPERTIES} -license ${BMA_LIC} -logLevel ${LOG_LEVEL}"
BMA_WORKING="<%=bma_details["BMA_WORKING"] %>"
BMA_TOKEN_SET=$BMATokensetName
BMA_OS_ID=bmaadmin
CLEANUP_DAYS=40 #The number of days to keep working directory log files


DATE=`date +%Y%m%d%H%M`

# Define if portal is in use # cannot use because of createServerProfile
#if [[ $TARGET_SERVER == *wps* ]]; then
#   BMA_OPTIONS="-properties ${BMA_PROP} -license ${BMA_LIC} -logLevel ${LOG_LEVEL} -portal"
#else
#   BMA_OPTIONS="-properties ${BMA_PROP} -license ${BMA_LIC} -logLevel ${LOG_LEVEL}"
#fi

######################## Functions

fatal() {
echo "$*" 1>&2
exit 1
}

debug() {
echo "DEBUG : $*"
}

function testConnection ()
{
    local serverProfile=$1
    cd $BMA_WORKING/tmp
    ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode testConnect -profile $serverProfile
    exitcode=$?
    if [ $exitcode -gt 0 ]
    then
        fatal "Connection Test of ${BMA_SERVER_PROF} failed, please refer to the BMA Logs for details."
    else
        debug "Connection Test of ${BMA_SERVER_PROF} was successful"
    fi
}

#in BASH v4 we can declare an array, otherwise we use a temp file
function arrayGet() { 
    local array=$1 index=$2
    local i="${array}_$index"
    printf '%s' "${!i}"
}

#In BASH v4 we can declare an array, otherwise we use a temp file
#This function is required to take a server profile from SVN and add in admin user/pass details that are stored in BSA
function createServerProfilePropertiesFile ()
{
    local tempFile="${BMA_WORKING}/tmp/serverProfProperties_${DATE}_"`date +%s | sha256sum | base64 | head -c 5` #we use this random string generator because we need the props file to be unique for this run
    local adminPassword=$WAS_ADMIN_PASSWORD
    local adminUser=$WAS_ADMIN_USER
    if [[ -z $adminPassword || -z $adminUser ]]; then
        fatal "One or more required Property values in the Component appear to be empty"
    else
        echo "adminPassword=${adminPassword}" > $tempFile
        echo "adminUser=${adminUser}" >> $tempFile
        echo "useRetrieveSigners=true" >> $tempFile
        profilePropertiesFile=$tempFile
    fi  
}

#This function is required to take a server profile from SVN and add in admin user/pass details that are stored in BSA
function createServerProfile()
{
    cd ${BMA_WORKING}/tmp
    local sourceProfile=$1
    local propFile=$2
    debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode createServerProfile -profile $sourceProfile  -profileProperties $propFile -outputProfile ${BMA_WORKING}/WAS80new.server"
    ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode createServerProfile -profile $sourceProfile  -profileProperties $propFile -outputProfile ${BMA_WORKING}/tmp/$BMA_SERVER_PROFILE.updated
    exitcode=$?
    if [[ $exitcode -gt 0 ]];   then
        fatal "Update of Server Profile $sourceProfile failed, please refer to the BMA Logs for details."
    else
        debug "Update of Server Profile $sourceProfile succeeded."
        #rm $propFile
        serverProfileNew=${BMA_WORKING}/tmp/$BMA_SERVER_PROFILE.updated
    fi
    updatePermissions ${BMA_WORKING}/tmp
}

function bmaSnapShot ()
{
    cd ${BMA_WORKING}/snapshots
    local serverProfile=$1  
    if [[ $TARGET_SERVER == *wps* ]]; then
        local snapshotOutputFile=`sed "s/.server/""/g" <<<"$BMA_SERVER_PROFILE".wpss`
        debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -portal -mode snapshot -profile $serverProfile -output ${BMA_WORKING}/snapshots/$snapshotOutputFile"
        ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -portal -mode snapshot -profile $serverProfile -output ${BMA_WORKING}/snapshots/$snapshotOutputFile
        exitcode=$?
    else
        local snapshotOutputFile=`sed "s/.server/""/g" <<<"$BMA_SERVER_PROFILE".xml`
        debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode snapshot -profile $serverProfile -output ${BMA_WORKING}/snapshots/$snapshotOutputFile"
        ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode snapshot -profile $serverProfile -output ${BMA_WORKING}/snapshots/$snapshotOutputFile
        exitcode=$?
    fi
    if [ $exitcode -gt 0 ]; then
        fatal "SnapShot of Server Profile $serverProfile failed, please refer to the BMA Logs for details."
    else
        debug "SnapShot of Server Profile $serverProfile succeeded: ${BMA_WORKING}/snapshots/$snapshotOutputFile.xml"
        snapshotFile=${BMA_WORKING}/snapshots/$snapshotOutputFile
        snapshotFileName=$snapshotOutputFile
    fi
    updatePermissions ${BMA_WORKING}/snapshots
}

function bmaInstallPreview ()
{
    local mode=$1
    local serverProfile=$2
    local configFile=$3
    cd ${BMA_WORKING}/$mode
    #runDeliver -mode preview -config C:\\temp\\VarMap.xml -tokens "Default Tokens" -profile C:\\temp\\WAS61.server -syncnodes
    if [[ $TARGET_SERVER == *wps* ]]; then
        if [ -z ${BMA_TOKEN_SET} ]
        then
            debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -portal -mode $mode -config $configFile -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}Report_${DATE}.report -syncnodes"
            ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -portal -mode $mode -config $configFile -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}Report_${DATE}.report -syncnodes
            exitcode=$?
        else
            debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -portal -mode $mode -config $configFile -tokens ${BMA_TOKEN_SET} -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}Report_${DATE}.report -syncnodes"
            ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -portal -mode $mode -config $configFile -tokens ${BMA_TOKEN_SET} -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}-${BMA_CONFIG_PACKAGE}-${BMA_SERVER_PROFILE}.report -syncnodes 
            exitcode=$?
        fi
    else
                if [ -z ${BMA_TOKEN_SET} ]
        then
            debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode $mode -config $configFile -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}Report_${DATE}.report -syncnodes"
            ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode $mode -config $configFile -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}Report_${DATE}.report -syncnodes
            exitcode=$?
        else
            debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode $mode -config $configFile -tokens ${BMA_TOKEN_SET} -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}Report_${DATE}.report -syncnodes"
            ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode $mode -config $configFile -tokens ${BMA_TOKEN_SET} -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}-${BMA_CONFIG_PACKAGE}-${BMA_SERVER_PROFILE}.report -syncnodes
            exitcode=$?
        fi
    fi  
    if [ $exitcode -gt 0 ]
    then
        fatal "$mode of Config Package: $configFile, for application ${APP_NAME} failed, please refer to the BMA Logs for details."
    else
        debug "$mode of Config Package: $configFile, for application ${APP_NAME} succeeded."
    fi
    reportFile=${BMA_WORKING}/reports/${mode}-${BMA_CONFIG_PACKAGE}-${BMA_SERVER_PROFILE}.report
    reportFileName=${mode}-${BMA_CONFIG_PACKAGE}-${BMA_SERVER_PROFILE}.report
    updatePermissions ${BMA_WORKING}/$mode
    updatePermissions ${BMA_WORKING}/reports
}

function driftReport ()
{
    local sourceSnap=$1
    local targetSnap=$2
    local reportName=$(basename $targetSnap|sed "s/.xml/""/g") #take the xml filename only and then strip .xml
    debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode compare -targetInput $targetSnap -sourceInput $sourceSnap -report ${BMA_WORKING}/reports/drift-$reportName.report"
    cd ${BMA_WORKING}/tmp
    ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode compare -targetInput $targetSnap -sourceInput $sourceSnap -report ${BMA_WORKING}/reports/drift-$reportName.report
    if [ $exitcode -gt 0 ]; then
        fatal "Drift Report of source: $sourceSnap and target: $targetSnap failed please refer to the BMA Logs for details."
    else
        debug "Drift Report of source: $sourceSnap and target: $targetSnap succeeded: ${BMA_WORKING}/reports/drift-$reportName.report"
    fi
    reportFile=${BMA_WORKING}/reports/drift-$reportName.report
    reportFileName=drift-$reportName.report
    updatePermissions ${BMA_WORKING}/reports
}

#NOTE
# For svn CLI, we must 'su - $BMA_OS_ID -c' so that the svn command is executed

function svnCheckOut ()
{
    local repoUrl=$1
    local svnUser=$2
    local svnPassword=$3
    cd ${SCM_WORKING}
    su $BMA_OS_ID -c "svn co --username $svnUser --password $svnPassword $repoUrl"
    exitcode=$?
    if [ $exitcode -gt 0 ];
    then
        fatal "SVN checkout of Repository: $repoUrl failed, please refer to the SVN Logs for details"
    else
        debug "SVN checkout of Repository: $repoUrl completed"
    fi              
}

function svnUpdate ()
{
    local svnRoot=$1
    cd ${svnRoot}
    while [[ -a ${svnRoot}/.svn/.lock ]]; do #this is needed because a lock is set on the svn repo so concurrent updates will not work
        sleep $[ ( $RANDOM % 5 )  + 1 ]s
    done    
    su $BMA_OS_ID -c "svn update"
    exitcode=$?
    if [ $exitcode -gt 0 ];
    then
        fatal "SVN update of Repository failed, please refer to the SVN Logs for details"
    else
        debug "SVN update of Repository succeeded"
    fi      
}

function svnAdd ()
{
    local targetFile=$1
    cd ${SCM_WORKING}
    su $BMA_OS_ID -c "svn add $targetFile"
    exitcode=$?
    if [ $exitcode -gt 0 ];
    then
        fatal "SVN add of file: $targetFile failed, please refer to the SVN Logs for details"
    else
        debug "SVN add of file: $targetFile completed"
    fi              
}

function svnCommit ()
{
    local targetFile=$1
    local comment=$2
    cd ${SCM_WORKING}
    su $BMA_OS_ID -c "svn commit -m \"$comment\" $targetFile"
    exitcode=$?
    if [ $exitcode -gt 0 ];
    then
        fatal "SVN commit of file: $targetFile failed, please refer to the SVN Logs for details"
    else
        debug "SVN commit of file: $targetFile completed"
    fi              
}

function exportLastRev ()
{
    local targetFile=$1 #fully qualified path and filename
    local targetDest=$2 #fully qualified path and filename
    #local lastRev=`svn info $targetFile | grep 'Last Changed Rev' | awk '{ print $4; }'`
    local lastRev=PREV
    su $BMA_OS_ID -c "svn export -r $lastRev $targetFile $targetDest"
    exitcode=$?
    if [ $exitcode -gt 0 ];
    then
        fatal "SVN export of file: $targetFile and revision: $lastRev failed, please refer to the SVN Logs for details"
    else
        debug "SVN export of file: $targetFile and revision: $lastRev completed"
        lastRevFile=$targetDest
    fi          
}

function updatePermissions ()
{
    local folderPath=$1
    chown $BMA_OS_ID:$BMA_OS_ID -R $folderPath
}

function cleanUp ()
{
local cleanUpPath=$1
find $cleanUpPath -type d -mtime +$CLEANUP_DAYS|xargs rm -rf
}

######################## Validate
#check for errors
if [[ -z $BMA_CONFIG_PACKAGE ]]; then
    if [[ $BMA_MODE != "snapshot" && $BMA_MODE != "testconnection" && $BMA_MODE != "drift" ]] ; then
        fatal "A value for the BMA Configuration Package name is missing"
    fi
fi  
if [[ -z $BMA_SERVER_PROFILE ]]; then
    fatal "A value for the BMA Server Profile name is missing"
fi
if [[ -n $BMA_CONFIG_PACKAGE ]]; then
    if [[ ! -a $SCM_CONFIG_PACKAGES_PATH/$BMA_CONFIG_PACKAGE ]]; then
        fatal "A value _bmaConfigPackage is set but the file is not found: $SCM_CONFIG_PACKAGES_PATH/$BMA_CONFIG_PACKAGE"
    fi  
fi      
#if [[ $BMA_PROP =~ '.wps' || $BMA_PROP =~ '.was' ]]; then
#   fatal "The properties file to use has not been set.  Value is: ${BMA_PROP} - Check the setting of Component property _bmaMiddlewareServer"
#fi 
######################## MAIN
#Start routine


echo "BMA Mode set to: $BMA_MODE"

case $BMA_MODE in
testconnection)
    svnUpdate $SCM_WORKING
    createServerProfilePropertiesFile
    debug "Server Profile Properties File: $profilePropertiesFile"
    createServerProfile $SCM_SERVER_PROFILES_PATH/$BMA_SERVER_PROFILE $profilePropertiesFile
    testConnection $serverProfileNew
    if [[ $result == "Success" ]]; then
        fatal "Failed BMA Connection Test, exiting Job."
    fi
    ;;
install)
    svnUpdate $SCM_WORKING
    svnUpdate $SCM_ARCHIVE_REPO_PATH
    createServerProfilePropertiesFile
    debug "Server Profile Properties File: $profilePropertiesFile"
    createServerProfile $SCM_SERVER_PROFILES_PATH/$BMA_SERVER_PROFILE $profilePropertiesFile
    bmaInstallPreview install $serverProfileNew $SCM_CONFIG_PACKAGES_PATH/$BMA_CONFIG_PACKAGE
    if [[ -a $SCM_REPORTS_PATH/$reportFileName ]]; then  
        debug "Updating Report in SVN: cp $reportFile $SCM_REPORTS_PATH/"
        cp $reportFile $SCM_REPORTS_PATH/
        svnCommit $SCM_REPORTS_PATH/$reportFileName "Updated Report from RPM Automation"
    else    
        debug "New Report.  Moving to SVN: cp $reportFile $SCM_REPORTS_PATH/"
        cp $reportFile $SCM_REPORTS_PATH/
        svnAdd $SCM_REPORTS_PATH/$reportFileName
        svnCommit $SCM_REPORTS_PATH/$reportFileName "New Report from RPM Automation"
    fi
    cleanUp $BMA_WORKING/install
    cleanUp $BMA_WORKING/tmp
    ;;
drift)
    svnUpdate $SCM_WORKING
    createServerProfilePropertiesFile
    debug "Server Profile Properties File: $profilePropertiesFile"
    createServerProfile $SCM_SERVER_PROFILES_PATH/$BMA_SERVER_PROFILE $profilePropertiesFile
    debug "Server Profile File: $serverProfileNew"
    bmaSnapShot $serverProfileNew
    if [[ -a $SCM_SNAPSHOTS_PATH/$snapshotFileName ]]; then
        debug "Updating snapshot in SVN: cp $snapshotFile $SCM_SNAPSHOTS_PATH/"
        debug "Drift report to be created."
        cp $snapshotFile $SCM_SNAPSHOTS_PATH/
        svnCommit $SCM_SNAPSHOTS_PATH/$snapshotFileName "Updated snapshot from RPM Automation"
        exportLastRev $SCM_SNAPSHOTS_PATH/$snapshotFileName ${BMA_WORKING}/tmp/$snapshotFileName
        driftReport $SCM_SNAPSHOTS_PATH/$snapshotFileName $lastRevFile
        if [[ -a $SCM_REPORTS_PATH/$reportFileName ]]; then  
            debug "Updating Report in SVN: cp $reportFile $SCM_REPORTS_PATH/"
            cp $reportFile $SCM_REPORTS_PATH/
            svnCommit ${SCM_REPORTS_PATH}/$reportFileName "Updated Report from RPM Automation"
        else    
            debug "New Report.  Moving to SVN: cp $reportFile $SCM_REPORTS_PATH/"
            cp $reportFile $SCM_REPORTS_PATH/
            svnAdd $SCM_REPORTS_PATH/$reportFileName
            svnCommit $SCM_REPORTS_PATH/$reportFileName "New Report from RPM Automation"
        fi
    else
        debug "New snapshot.  No Drift Report will be created"
        debug "Moving to SVN: cp $snapshotFile $SCM_SNAPSHOTS_PATH/$snapshotFile"
        cp $snapshotFile $SCM_SNAPSHOTS_PATH/$
        svnAdd $SCM_SNAPSHOTS_PATH/$snapshotFileName
        svnCommit $SCM_SNAPSHOTS_PATH/$snapshotFileName "New snapshot from RPM Automation"
    fi
    cleanUp $BMA_WORKING/snapshots
    cleanUp $BMA_WORKING/tmp
    ;;
preview)
    svnUpdate $SCM_WORKING
    svnUpdate $SCM_ARCHIVE_REPO_PATH
    createServerProfilePropertiesFile
    debug "Server Profile Properties File: $profilePropertiesFile"
    createServerProfile $SCM_SERVER_PROFILES_PATH/$BMA_SERVER_PROFILE $profilePropertiesFile
    bmaInstallPreview preview $serverProfileNew $SCM_CONFIG_PACKAGES_PATH/$BMA_CONFIG_PACKAGE
    if [[ -a $SCM_REPORTS_PATH/$reportFileName ]]; then  
        debug "Updating Report in SVN: cp $reportFile $SCM_REPORTS_PATH/"
        cp $reportFile $SCM_REPORTS_PATH/
        svnCommit $SCM_REPORTS_PATH/$reportFileName "Updated Report from RPM Automation"
    else    
        debug "New Report.  Moving to SVN: cp $reportFile $SCM_REPORTS_PATH/"
        cp $reportFile $SCM_REPORTS_PATH/
        svnAdd $SCM_REPORTS_PATH/$reportFileName
        svnCommit $reportFile "New Report from RPM Automation"
    fi  
    cleanUp $BMA_WORKING/preview
    cleanUp $BMA_WORKING/tmp
    ;;
snapshot)
    svnUpdate $SCM_WORKING
    createServerProfilePropertiesFile
    debug "Server Profile Properties File: $profilePropertiesFile"
    createServerProfile $SCM_SERVER_PROFILES_PATH/$BMA_SERVER_PROFILE $profilePropertiesFile
    debug "Server Profile File: $serverProfileNew"
    bmaSnapShot $serverProfileNew
    if [[ -a $SCM_SNAPSHOTS_PATH/$snapshotFileName ]]; then
        debug "Updating snapshot in SVN: cp $snapshotFile $SCM_SNAPSHOTS_PATH/"
        cp $snapshotFile $SCM_SNAPSHOTS_PATH/
        svnCommit $SCM_SNAPSHOTS_PATH/$snapshotFileName "Updated snapshot from RPM Automation"
    else
        debug "New snapshot.  Moving to SVN: cp $snapshotFile $SCM_SNAPSHOTS_PATH/"
        cp $snapshotFile $SCM_SNAPSHOTS_PATH/
        svnAdd $SCM_SNAPSHOTS_PATH/$snapshotFileName
        svnCommit $SCM_SNAPSHOTS_PATH/$snapshotFileName "New snapshot from RPM Automation"
    fi
    cleanUp $BMA_WORKING/snapshots
    cleanUp $BMA_WORKING/tmp
    ;;
*)
    echo "BMA_MODE property not set.  Values are |test_connection|snapshot|drift|preview|install|"
    exit 1
esac

END
#---------------------- End Ruby Shell Wrapper ----------------------------#

#---------------------- Methods ----------------------------#
def execute_bma(script_file, options = {})
  # get the body of the action
  bma_details = YAML.load(SS_integration_details)
  os_platform = get_option(bma_details, "BMA_PLATFORM", "nux")
  os = @transport.os_platform(os_platform)
  os_details = OS_PLATFORMS[os]
  content = File.open(script_file).read
  transfer_properties = get_option(options, "transfer_properties",{})
  keyword_items = get_keyword_items(content)
  params_filter = get_option(keyword_items, "RPM_PARAMS_FILTER")
  params_filter = get_option(options, "transfer_prefix", DEFAULT_PARAMS_FILTER)
  transfer_properties.merge!(get_transfer_properties(params_filter, strip_prefix = true))
  log "#----------- Executing Script on Remote BMA Server -----------------#"
  log "# Script: #{script_file}"
  result = "No servers to execute on"
  servers = @rpm.get_server_list
  message_box "OS Platform: #{os_details["name"]}"
  raise "No servers selected for: #{os_details["name"]}" if servers.size == 0
  log "# #{os_details["name"]} - Targets: #{servers.inspect}"
  log "# Setting Properties:"
  add_channel_properties(transfer_properties, servers, os)
  brpd_compatibility(transfer_properties)
  transfer_properties.each{|k,v| log "\t#{k} => #{v}" }
  shebang = read_shebang(os, content)
  log "Shebang: #{shebang.inspect}"
  wrapper_path = build_wrapper_script(os, shebang, transfer_properties, {"script_target" => File.basename(script_file)})
  log "# Wrapper: #{wrapper_path}"
  target_path = @nsh.nsh_path(transfer_properties["RPM_CHANNEL_ROOT"])
  log "# Copying script to target: "
  clean_line_breaks(os, script_file, content)
  result = @nsh.ncp(server_dns_names(servers), script_file, target_path)
  log result
  log "# Executing script on target via wrapper:"
  result = @nsh.script_exec(server_dns_names(servers), wrapper_path, target_path)
  log result
  result
end

def scm_command_paths(properties)
  scm_base_dir = "/opt/bmc/bma/profile" #@p.required("SVN_WorkingDir")
  properties["SCM_WORKING"] = scm_base_dir
  properties["SCM_SERVER_PROFILES_PATH"] = "#{scm_base_dir}/#{@p.SS_environment}/server_profiles"
  properties["SCM_SNAPSHOTS_PATH"] = "#{scm_base_dir}/#{@p.SS_environment}/snapshots"
  properties["SCM_REPORTS_PATH"] = "#{scm_base_dir}/#{@p.SS_environment}/reports"
  properties["SCM_CONFIG_PACKAGES_PATH"] = "#{scm_base_dir}/#{@p.SS_environment}/config_packages"
  properties["SCM_ARCHIVE_REPO_PATH"] = "/opt/bmc/svn_ears/#{@p.SS_environment}"
end

#---------------------- Variables --------------------------#
#content_items = @p.required("instance_#{@p.SS_component}_content") # This is coming from the staging step
bma_details = YAML.load(SS_integration_details)
transport = "nsh"
bma_mode = @p.get("BMA Action", "snapshot")
bma_config_package = @p.required("BMA_ConfigPackage") if ["preview", "install"].include?(bma_mode)
servers = @rpm.get_server_list

#---------------------- Main Body --------------------------#
# Note - each of the bma_details are consumed in the erb of the script
if !defined?(@nsh)
  @rpm.log "Loading transport modules for: #{transport}"
  rpm_load_module("transport_#{transport}", "dispatch_#{transport}")
end
  
# These are the component properties to transfer
transfer_properties = {
  "BMA_MODE" => bma_mode,
  "TARGET_SERVER" => servers.keys[0],
  "BMA_SERVER_PROFILE" => @p.required("BMA_ServerProfile")
}
transfer_properties["BMA_CONFIG_PACKAGE"] = bma_config_package if defined?(bma_config_package)

# Abstract the location of scm checkout paths
scm_command_paths(transfer_properties)

# Note RPM_CHANNEL_ROOT will be set in the run script routine
action_txt = ERB.new(script).result(binding)
@rpm.message_box "Executing BMA Action: #{transfer_properties["BMA_MODE"]}"
script_file = @transport.make_temp_file(action_txt)
#result = @transport.execute_script(script_file)
#@rpm.log "SRUN Result: #{result.inspect}"
#pack_response("output_status", "Successfully packaged - #{File.basename(result["instance_path"])}")

params["direct_execute"] = true


