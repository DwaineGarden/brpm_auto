#   BMA General Action Script
#   BJB 1/3/2015 Adapted from
#   S Dunbar BMC @ 10/10/2014
######################## Variables
BMA_DIR="/opt/bmc/bma"
LOG_LEVEL="ERROR"   
BMA_LIC="/opt/bmc/BARA_perm.lic"
BMA_PROP="/opt/bmc/bma_properties/setupDeliver."??_bmaMiddlewareServer??
BMA_OPTIONS="-properties ${BMA_PROP} -license ${BMA_LIC} -logLevel ${LOG_LEVEL}"
BMA_WORKING="/opt/bmc/bma_working"
SVN_WORKING="/opt/bmc/svn_bwk_bma"

BMA_CONFIG_PACKAGE=??_bmaConfigPackage??
BMA_MODE=??_bmaMode??
BMA_SERVER_PROFILE=??_bmaServerProfile??
SVN_SERVER_PROFILES=$SVN_WORKING/??_envCustomer??/??_envPlatform??/server_profiles
SVN_SNAPSHOTS=$SVN_WORKING/??_envCustomer??/??_envPlatform??/snapshots
SVN_REPORTS=$SVN_WORKING/??_envCustomer??/??_envPlatform??/reports
SVN_CONFIG_PACKAGES=$SVN_WORKING/??_envCustomer??/??_envPlatform??/config_packages
SVN_ARCHIVE_REPO=/opt/bmc/svn_ears/??_envCustomer??/??_envPlatform??
BMA_TOKEN_SET=??_bmaTokensetName??
BMA_OS_ID=bmaadmin
CLEANUP_DAYS=40 #The number of days to keep working directory log files


DATE=`date +%Y%m%d%H%M`

# Define if portal is in use # cannot use because of createServerProfile
#if [[ ??_bmaMiddlewareServer?? == *wps* ]]; then
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
    local adminPassword=??_adminPassword??
    local adminUser=??_adminUser??
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
    ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode createServerProfile -profile $sourceProfile  -profileProperties $propFile -outputProfile ${BMA_WORKING}/tmp/??_bmaServerProfile??.updated
    exitcode=$?
    if [[ $exitcode -gt 0 ]];   then
        fatal "Update of Server Profile $sourceProfile failed, please refer to the BMA Logs for details."
    else
        debug "Update of Server Profile $sourceProfile succeeded."
        #rm $propFile
        serverProfileNew=${BMA_WORKING}/tmp/??_bmaServerProfile??.updated
    fi
    updatePermissions ${BMA_WORKING}/tmp
}

function bmaSnapShot ()
{
    cd ${BMA_WORKING}/snapshots
    local serverProfile=$1  
    if [[ ??_bmaMiddlewareServer?? == *wps* ]]; then
        local snapshotOutputFile=`sed "s/.server/""/g" <<<"??_bmaServerProfile??".wpss`
        debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -portal -mode snapshot -profile $serverProfile -output ${BMA_WORKING}/snapshots/$snapshotOutputFile"
        ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -portal -mode snapshot -profile $serverProfile -output ${BMA_WORKING}/snapshots/$snapshotOutputFile
        exitcode=$?
    else
        local snapshotOutputFile=`sed "s/.server/""/g" <<<"??_bmaServerProfile??".xml`
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
    #runDeliver -mode preview -config C:\temp\VarMap.xml -tokens "Default Tokens" -profile C:\temp\WAS61.server -syncnodes
    if [[ ??_bmaMiddlewareServer?? == *wps* ]]; then
        if [ -z ${BMA_TOKEN_SET} ]
        then
            debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -portal -mode $mode -config $configFile -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}Report_${DATE}.report -syncnodes"
            ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -portal -mode $mode -config $configFile -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}Report_${DATE}.report -syncnodes 2>/dev/null
            exitcode=$?
        else
            debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -portal -mode $mode -config $configFile -tokens ${BMA_TOKEN_SET} -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}Report_${DATE}.report -syncnodes"
            ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -portal -mode $mode -config $configFile -tokens ${BMA_TOKEN_SET} -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}-${BMA_CONFIG_PACKAGE}-${BMA_SERVER_PROFILE}.report -syncnodes 2>/dev/null
            exitcode=$?
        fi
    else
        if [ -z ${BMA_TOKEN_SET} ]
        then
            debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode $mode -config $configFile -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}Report_${DATE}.report -syncnodes"
            ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode $mode -config $configFile -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}Report_${DATE}.report -syncnodes 2>/dev/null
            exitcode=$?
        else
            debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode $mode -config $configFile -tokens ${BMA_TOKEN_SET} -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}Report_${DATE}.report -syncnodes"
            ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode $mode -config $configFile -tokens ${BMA_TOKEN_SET} -profile $serverProfile -report ${BMA_WORKING}/reports/${mode}-${BMA_CONFIG_PACKAGE}-${BMA_SERVER_PROFILE}.report -syncnodes 2>/dev/null
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
    cd ${SVN_WORKING}
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
    cd ${SVN_WORKING}
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
    cd ${SVN_WORKING}
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
    if [[ ! -a $SVN_CONFIG_PACKAGES/$BMA_CONFIG_PACKAGE ]]; then
        fatal "A value _bmaConfigPackage is set but the file is not found: $SVN_CONFIG_PACKAGES/$BMA_CONFIG_PACKAGE"
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
    svnUpdate $SVN_WORKING
    createServerProfilePropertiesFile
    debug "Server Profile Properties File: $profilePropertiesFile"
    createServerProfile $SVN_SERVER_PROFILES/$BMA_SERVER_PROFILE $profilePropertiesFile
    testConnection $serverProfileNew
    if [[ $result == "Success" ]]; then
        fatal "Failed BMA Connection Test, exiting Job."
    fi
    ;;
install)
    svnUpdate $SVN_WORKING
    svnUpdate $SVN_ARCHIVE_REPO
    createServerProfilePropertiesFile
    debug "Server Profile Properties File: $profilePropertiesFile"
    createServerProfile $SVN_SERVER_PROFILES/$BMA_SERVER_PROFILE $profilePropertiesFile
    bmaInstallPreview install $serverProfileNew $SVN_CONFIG_PACKAGES/$BMA_CONFIG_PACKAGE
    if [[ -a $SVN_REPORTS/$reportFileName ]]; then  
        debug "Updating Report in SVN: cp $reportFile $SVN_REPORTS/"
        cp $reportFile $SVN_REPORTS/
        svnCommit $SVN_REPORTS/$reportFileName "Updated Report from BSA Automation"
    else    
        debug "New Report.  Moving to SVN: cp $reportFile $SVN_REPORTS/"
        cp $reportFile $SVN_REPORTS/
        svnAdd $SVN_REPORTS/$reportFileName
        svnCommit $SVN_REPORTS/$reportFileName "New Report from BSA Automation"
    fi
    cleanUp $BMA_WORKING/install
    cleanUp $BMA_WORKING/tmp
    ;;
drift)
    svnUpdate $SVN_WORKING
    createServerProfilePropertiesFile
    debug "Server Profile Properties File: $profilePropertiesFile"
    createServerProfile $SVN_SERVER_PROFILES/$BMA_SERVER_PROFILE $profilePropertiesFile
    debug "Server Profile File: $serverProfileNew"
    bmaSnapShot $serverProfileNew
    if [[ -a $SVN_SNAPSHOTS/$snapshotFileName ]]; then
        debug "Updating snapshot in SVN: cp $snapshotFile $SVN_SNAPSHOTS/"
        debug "Drift report to be created."
        cp $snapshotFile $SVN_SNAPSHOTS/
        svnCommit $SVN_SNAPSHOTS/$snapshotFileName "Updated snapshot from BSA Automation"
        exportLastRev $SVN_SNAPSHOTS/$snapshotFileName ${BMA_WORKING}/tmp/$snapshotFileName
        driftReport $SVN_SNAPSHOTS/$snapshotFileName $lastRevFile
        if [[ -a $SVN_REPORTS/$reportFileName ]]; then  
            debug "Updating Report in SVN: cp $reportFile $SVN_REPORTS/"
            cp $reportFile $SVN_REPORTS/
            svnCommit ${SVN_REPORTS}/$reportFileName "Updated Report from BSA Automation"
        else    
            debug "New Report.  Moving to SVN: cp $reportFile $SVN_REPORTS/"
            cp $reportFile $SVN_REPORTS/
            svnAdd $SVN_REPORTS/$reportFileName
            svnCommit $SVN_REPORTS/$reportFileName "New Report from BSA Automation"
        fi
    else
        debug "New snapshot.  No Drift Report will be created"
        debug "Moving to SVN: cp $snapshotFile $SVN_SNAPSHOTS/$snapshotFile"
        cp $snapshotFile $SVN_SNAPSHOTS/$
        svnAdd $SVN_SNAPSHOTS/$snapshotFileName
        svnCommit $SVN_SNAPSHOTS/$snapshotFileName "New snapshot from BSA Automation"
    fi
    cleanUp $BMA_WORKING/snapshots
    cleanUp $BMA_WORKING/tmp
    ;;
preview)
    svnUpdate $SVN_WORKING
    svnUpdate $SVN_ARCHIVE_REPO
    createServerProfilePropertiesFile
    debug "Server Profile Properties File: $profilePropertiesFile"
    createServerProfile $SVN_SERVER_PROFILES/$BMA_SERVER_PROFILE $profilePropertiesFile
    bmaInstallPreview preview $serverProfileNew $SVN_CONFIG_PACKAGES/$BMA_CONFIG_PACKAGE
    if [[ -a $SVN_REPORTS/$reportFileName ]]; then  
        debug "Updating Report in SVN: cp $reportFile $SVN_REPORTS/"
        cp $reportFile $SVN_REPORTS/
        svnCommit $SVN_REPORTS/$reportFileName "Updated Report from BSA Automation"
    else    
        debug "New Report.  Moving to SVN: cp $reportFile $SVN_REPORTS/"
        cp $reportFile $SVN_REPORTS/
        svnAdd $SVN_REPORTS/$reportFileName
        svnCommit $reportFile "New Report from BSA Automation"
    fi  
    cleanUp $BMA_WORKING/preview
    cleanUp $BMA_WORKING/tmp
    ;;
snapshot)
    svnUpdate $SVN_WORKING
    createServerProfilePropertiesFile
    debug "Server Profile Properties File: $profilePropertiesFile"
    createServerProfile $SVN_SERVER_PROFILES/$BMA_SERVER_PROFILE $profilePropertiesFile
    debug "Server Profile File: $serverProfileNew"
    bmaSnapShot $serverProfileNew
    if [[ -a $SVN_SNAPSHOTS/$snapshotFileName ]]; then
        debug "Updating snapshot in SVN: cp $snapshotFile $SVN_SNAPSHOTS/"
        cp $snapshotFile $SVN_SNAPSHOTS/
        svnCommit $SVN_SNAPSHOTS/$snapshotFileName "Updated snapshot from BSA Automation"
    else
        debug "New snapshot.  Moving to SVN: cp $snapshotFile $SVN_SNAPSHOTS/"
        cp $snapshotFile $SVN_SNAPSHOTS/
        svnAdd $SVN_SNAPSHOTS/$snapshotFileName
        svnCommit $SVN_SNAPSHOTS/$snapshotFileName "New snapshot from BSA Automation"
    fi
    cleanUp $BMA_WORKING/snapshots
    cleanUp $BMA_WORKING/tmp
    ;;
*)
    echo "BMA_MODE property not set.  Values are |snapshot|drift|preview|install|"
    exit 1
esac
