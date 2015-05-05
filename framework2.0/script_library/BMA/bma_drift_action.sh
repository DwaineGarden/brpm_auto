#!/bin/bash
##################################################################
# BJB - BMC Software 2015

#####Variables
BMA_DIR=<%=integration_details["BMA_HOME"] %> #"/opt/bmc/bma"
LOG_LEVEL="ERROR"
BMA_LIC=<%=integration_details["BMA_LICENSE"] %> #"/opt/bmc/BARA_perm.lic"
BMA_PROP=<%=bma_properties_path %> #"/opt/bmc/bma_properties/setupDeliver."??_bmaMiddlewareServer??
BMA_OPTIONS="-properties ${BMA_PROP} -license ${BMA_LIC} -logLevel ${LOG_LEVEL}"
BMA_WORKING=<%=integration_details["BMA_WORKING"] %> #"/opt/bmc/bma_working"
BMA_MODE=<%=bma_action %>
BMA_SNAPSHOTS_DIR=<%=bma_snapshots_path %>
BMA_TOKEN_SET=<%=bma_tokenset_name %>
BMA_REPORTS_DIR=${BMA_WORKING}/reports
BMA_OS_ID=bmaadmin
CLEANUP_DAYS=40 #The number of days to keep working directory log files

DATE=<%=@timestamp %>

fatal() {
	echo "$*"
	exit 1
}

debug() {
	echo "DEBUG : $*"
}

function cleanUp () {
	local cleanUpPath=$1
	find $cleanUpPath -type d -mtime +$CLEANUP_DAYS|xargs rm -rf
}

function bmaDriftReport ()
{
    local sourceSnap=$1
    local targetSnap=$2
    local reportName=$(basename $targetSnap|sed "s/.xml/""/g") #take the xml filename only and then strip .xml
    debug "SENDING: ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode compare -targetInput $targetSnap -sourceInput $sourceSnap -report ${BMA_REPORTS_DIR}/drift-$reportName.report"
    cd ${BMA_WORKING}/tmp
    ${BMA_DIR}/cli/runDeliver.sh ${BMA_OPTIONS} -mode compare -targetInput $targetSnap -sourceInput $sourceSnap -report ${BMA_REPORTS_DIR}/drift-$reportName.report
    exitcode=$?
	if [ $exitcode -gt 0 ]; then
        fatal "Drift Report of source: $sourceSnap and target: $targetSnap failed please refer to the BMA Logs for details."
    else
        debug "Drift Report of source: $sourceSnap and target: $targetSnap succeeded: ${BMA_REPORTS_DIR}/drift-$reportName.report"
    fi
    reportFile=${BMA_REPORTS_DIR}/drift-$reportName.report
    reportFileName=drift-$reportName.report
    #updatePermissions ${BMA_REPORTS_DIR}
}

#
#MAIN SCRIPT
#

export JAVA_HOME=$BMA_DIR/jre

######################## MAIN ###############################
#Start routine

echo "#-------------------------------------------------------#"
echo "#     BMA Execution"
echo "#-------------------------------------------------------#"
echo "=> BMA Mode set to: $BMA_MODE"

bmaDriftReport <%=bma_compare_snapshot1 %> <%=bma_compare_snapshot2 %>
if [ `echo $?` -gt 0 ]
then
	echo "Failed BMA Drift, exiting Job."
	exit 1
fi
