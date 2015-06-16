##################################################################
#!/bin/bash

#set -x
#  Custom RPD action for BMA CLI orchestration.
#  SDunbar BMC
#Modified by:	Santosh Kunnothmannur(BMC), Brady Byrd
# Development only variables
# This are used to override production values for the development purposes
#####FOR PACKAGE
#RPM_environment="LAST2"
#BMA_MW_PLATFORM="was85"
#BMA_SERVER_PROF="last2stpCell.server"
#RPM_application_NAME="STP"
#BMA_CONFIG_PACKAGE=""
#BMA_ACTION=
#BMA_TOKEN_SET=

#####Variables
BMA_DIR=<%=@bma["home_dir"] %> #"/opt/bmc/bma"
LOG_LEVEL=<%=@bma["log_level"] %>
BMA_LIC=<%=@bma["license"] %> #"/opt/bmc/BARA_perm.lic"
BMA_PROP=<%=@bma["properties"] %> #"/opt/bmc/bma_properties/setupDeliver."??_bmaMiddlewareServer??
BMA_OPTIONS="-properties ${BMA_PROP} -license ${BMA_LIC} -logLevel ${LOG_LEVEL}"
BMA_WORKING=<%=@bma["working_dir"] %> #"/opt/bmc/bma_working"

BMA_CONFIG_PACKAGE=<%=File.basename(bma_config_package_path) %>
BMA_MODE=<%=@bma["action"] %>
BMA_SERVER_PROFILE=<%=File.basename(bma_server_profile_path) %>
BMA_SERVER_PROFILES_DIR=<%=File.dirname(bma_server_profile_path) %>
BMA_CONFIG_PACKAGES_DIR=<%=File.dirname(bma_config_package_path) %>
BMA_TOKEN_SET=<%=bma_tokenset_name %>
BMA_SNAPSHOTS_DIR=<%=@bma["snapshots_dir"] %>
BMA_ARCHIVE_DIR=<%=@bma["archive_dir"] %>
BMA_REPORTS_DIR=<%=@bma["reports_dir"] %>

BMA_OS_ID=bmaadmin
CLEANUP_DAYS=40 #The number of days to keep working directory log files
DATE=<%=@timestamp %>

######################## MAIN

if [[ ${BMA_MW_PLATFORM} == *portal* ]]; then
	BMA_OPTIONS="-properties ${BMA_PROP} -license ${BMA_LIC} -logLevel ${LOG_LEVEL} -portal"
else
	BMA_OPTIONS="-properties ${BMA_PROP} -license ${BMA_LIC} -logLevel ${LOG_LEVEL}"
fi

fatal() {
echo "$*"
exit 1
}

debug() {
echo "DEBUG : $*"
}
#in BASH v4 we can declare an array, otherwise we use a temp file
function arrayGet() { 
    local array=$1 index=$2
    local i="${array}_$index"
    printf '%s' "${!i}"
}

# Decodes an ecrypted BRPM string
function decrypt() {
    local secret=$1
    local rev=''
    copy="${secret/__SS__/}"
    copy=`echo $copy | base64 -d`
    len=${#copy}
    for((i=$len-1;i>=0;i--)); do rev="$rev${copy:$i:1}"; done
    copy=`echo $rev | base64 -d`
    ReturnVal=$copy
}

function cleanUp ()
{
local cleanUpPath=$1
find $cleanUpPath -type d -mtime +$CLEANUP_DAYS|xargs rm -rf
}

function testConnection ()
{
	cd $BMA_WORKING
	${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode testConnect -profile ${BMA_SERVER_PROFILES_DIR}/${BMA_SERVER_PROFILE}
	exitcode=$?
	if [ $exitcode -gt 0 ]
	then
		fatal "Connection Test of ${BMA_SERVER_PROFILE} failed, please refer to the BMA Logs for details."
	else
		debug "Connection Test of ${BMA_SERVER_PROFILE} was successful"
	fi
}


function bmaSnapShot ()
{
	cd ${BMA_SNAPSHOTS_DIR}
	debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode snapshot -profile ${BMA_SERVER_PROFILES_DIR}/${BMA_SERVER_PROFILE} -output ${BMA_SNAPSHOTS_DIR}/snapshot_${BMA_SERVER_PROFILE}_${DATE}.xml 2>/dev/null"
	${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode snapshot -profile ${BMA_SERVER_PROFILES_DIR}/${BMA_SERVER_PROFILE} -output ${BMA_SNAPSHOTS_DIR}/snapshot_${BMA_SERVER_PROFILE}_${DATE}.xml 2>/dev/null
	exitcode=$?
	if [ $exitcode -gt 0 ]
	then
		fatal "SnapShot of Server Profile ${BMA_SERVER_PROFILE} failed, please refer to the BMA Logs for details."
	else
		debug "SnapShot of Server Profile ${BMA_SERVER_PROFILE} succeeded."
	fi
}


function bmaInstallPreview ()
{
	cd ${BMA_WORKING}/$1

	#check if a token set is passed and install BMA config package
	if [ -z ${BMA_TOKEN_SET} ]
	then
		debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode $1 -config ${BMA_CONFIG_PACKAGES_DIR}/${BMA_CONFIG_PACKAGE} -profile ${BMA_SERVER_PROFILES_DIR}/${BMA_SERVER_PROFILE} -report ${BMA_WORKING}/reports/${RPM_environment}_${RPM_application}_${1}Report_${DATE}.report -syncnodes"
		${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode $1 -config ${BMA_CONFIG_PACKAGES_DIR}/${BMA_CONFIG_PACKAGE} -profile ${BMA_SERVER_PROFILE} -report ${BMA_REPORTS_DIR}/${RPM_environment}_${RPM_application}_${1}Report_${DATE}.report -syncnodes 2>/dev/null
		exitcode=$?
	elif [[ ${BMA_MW_PLATFORM} == *portal* ]]; 
#Check if it is a portal wpss deploy	
	then
		debug "Portal wpss deploy"
		debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode $1 -input ${BMA_CONFIG_PACKAGES_DIR}/${BMA_CONFIG_PACKAGE} -tokens ${BMA_TOKEN_SET} -profile ${CLEARCASE_VIEW}/serverprofiles/$RPM_environment/${BMA_SERVER_PROF} -report ${BMA_REPORTS_DIR}/${RPM_environment}_${RPM_application}_${1}PortalReport_${DATE}.report "
		${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode $1 -input ${BMA_CONFIG_PACKAGES_DIR}/${BMA_CONFIG_PACKAGE} -tokens ${BMA_TOKEN_SET} -profile ${BMA_SERVER_PROFILES_DIR}/${BMA_SERVER_PROFILE} -report ${BMA_REPORTS_DIR}/${RPM_environment}_${RPM_application}_${1}PortalReport_${DATE}.report 2>/dev/null
#		/bmc/bma/cli/runDeliver.sh -properties /bmc/properties/setupDeliver_portal80.properties -license /bmc/bma/TexasHealth5997ELO_ML.lic -logLevel ERROR -portal -mode install -input /eastage/views/MW_LW_CFG_LOCAL/mwlw/MWLWRelease/configurations/STP/stp.wpss -tokens stp-LAST2 -profile /eastage/views/MW_UP_CFG_LOCAL/mwup/MWUPRelease/serverprofiles/LAST2/last2stpCell.server -report /bmc/bma_working/reports/installPortalReport_201405281543.report 
		exitcode=$?
		
	else
		debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode $1 -config ${BMA_CONFIG_PACKAGES_DIR}/${BMA_CONFIG_PACKAGE} -tokens ${BMA_TOKEN_SET} -profile ${BMA_SERVER_PROFILES_DIR}/${BMA_SERVER_PROFILE} -report ${BMA_REPORTS_DIR}/${RPM_environment}_${RPM_application}_${1}Report_${DATE}.report -syncnodes"
		${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode $1 -config ${BMA_CONFIG_PACKAGES_DIR}/${BMA_CONFIG_PACKAGE} -tokens ${BMA_TOKEN_SET} -profile ${BMA_SERVER_PROFILES_DIR}/${BMA_SERVER_PROFILE} -report ${BMA_WORKING}/reports/${RPM_environment}_${RPM_application}_${1}Report_${DATE}.report -syncnodes 2>/dev/null
		exitcode=$?

	fi

	if [ $exitcode -gt 0  ]
	then
		debug "Exitcode value is $exitcode - Deployment failed"
		fatal "$1 of Config Package: $BMA_CONFIG_PACKAGE, for application ${RPM_application} failed, please refer to the BMA Logs /bmc/bma_working/install/ for details"
	fi
}

function bmaDriftReport ()
{
    local sourceSnap=$1
    local targetSnap=$2
    local reportName=$(basename $targetSnap|sed "s/.xml/""/g") #take the xml filename only and then strip .xml
    debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode compare -targetInput $targetSnap -sourceInput $sourceSnap -report ${BMA_REPORTS_DIR}/drift-$reportName.report"
    cd ${BMA_WORKING}/tmp
    ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode compare -targetInput $targetSnap -sourceInput $sourceSnap -report ${BMA_REPORTS_DIR}/drift-$reportName.report
    if [ $exitcode -gt 0 ]; then
        fatal "Drift Report of source: $sourceSnap and target: $targetSnap failed please refer to the BMA Logs for details."
    else
        debug "Drift Report of source: $sourceSnap and target: $targetSnap succeeded: ${BMA_REPORTS_DIR}/drift-$reportName.report"
    fi
    reportFile=${BMA_REPORTS_DIR}/drift-$reportName.report
    reportFileName=drift-$reportName.report
    updatePermissions ${BMA_REPORTS_DIR}
}

######################## Validate ##########################
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
    if [[ ! -a $BMA_CONFIG_PACKAGES_DIR/$BMA_CONFIG_PACKAGE ]]; then
        fatal "A value _bmaConfigPackage is set but the file is not found: $BMA_CONFIG_PACKAGES_DIR/$BMA_CONFIG_PACKAGE"
    fi  
fi      

#
#MAIN SCRIPT
#

export JAVA_HOME=$BMA_DIR/jre

######################## MAIN ###############################
#Start routine

echo "#-------------------------------------------------------#"
echo "#     BMA Execution - #{BMA_MODE}"
echo "#-------------------------------------------------------#"

case $BMA_MODE in
testconnection)
	testConnection
	if [ `echo $?` -gt 0 ]
	then
		echo "Failed BMA Connection Test, exiting Job."
		exit 1
	fi
	;;
install)
	bmaInstallPreview install
	if [ `echo $?` -gt 0 ]
	then
		echo "Failed BMA Preview, exiting Job."
		exit 1
	fi
	;;
drift)
	#bmaDriftReport <%=bma_compare_snapshot1 %> <%=bma_compare_snapshot2 %>
	if [ `echo $?` -gt 0 ]
	then
		echo "Failed BMA Drift, exiting Job."
		exit 1
	fi
	;;
preview)
	bmaInstallPreview preview
	if [ `echo $?` -gt 0 ]
	then
		echo "Failed BMA Preview, exiting Job."
		exit 1
	fi
	;;
snapshot)
	bmaSnapShot
	if [ `echo $?` -gt 0 ]
	then
		echo "Failed BMA SnapShot, exiting Job."
		exit 1
	fi
	;;
*)
	echo "BMA_MODE property not set.  Values are |snapshot|drift|preview|install|testconnection"
	exit 1
esac
