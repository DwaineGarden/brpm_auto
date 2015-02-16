#!/bin/sh

# Consumes
#	VL_DISPATCH_TARGET_HOST
#	VL_CHANNEL_ROOT
#	CITI_EMT_WAS_HOME
#	CITI_WAS_ADMIN_USER
#	CITI_BMA_TOKEN_CELL_NAME
#	CITI_BMA_TOKEN_CLUSTER_NAME
#	CITI_BMA_TOKEN_SERVER_NAME or CITI_BMA_TOKEN_NODE_NAME

echo -e "\n\n\n#############################################################"
echo -e "##"
echo -e "#############################################################\n"
DATE1=`date +"%m/%d/%y"`
TIME1=`date +"%H:%M:%S"`
echo "INFO: Performing action: $CITI_WAS_START_STOP_ACTION"
echo "INFO: Start of Start/Stop execution on Server $VL_DISPATCH_TARGET_HOST"
echo "INFO: Start/Stop on Server Start Time: $DATE1 $TIME1"
echo "INFO: Start/Stop Target: $VL_DISPATCH_TARGET_HOST"
echo -e "\nINFO: Script Execution in progress ... \n"

#VL_CONTENT_PATH="/tmp"	
#CITI_EMT_WAS_HOME="/opt/middleware/emt-wasce/3.0.0.3"
#CITI_BMA_TOKEN_CLUSTER_NAME="cloudappCluster"
#CITI_BMA_TOKEN_CELL_NAME="cloudappCell"
#CITI_WAS_ADMIN_USER=cloudusr

if [ ! "$VL_CHANNEL_ROOT" ]
then
   echo -e "ERROR: VL_CHANNEL_ROOT variable needs to be set."
   exit 1
fi

if [ ! "$CITI_EMT_WAS_HOME" ]
then
   echo -e "ERROR: CITI_EMT_WAS_HOME variable needs to be set."
   exit 1
fi

if [ ! "$CITI_WAS_ADMIN_USER" ]
then
   echo -e "ERROR: CITI_WAS_ADMIN_USER variable needs to be set."
   exit 1
fi


if [ ! "$CITI_BMA_TOKEN_CELL_NAME" ]
then
   echo -e "ERROR: CITI_BMA_TOKEN_CELL_NAME variable needs to be set."
   exit 1
fi

if [ ! "$CITI_BMA_TOKEN_CLUSTER_NAME" ]
then
   if [ ! "$CITI_BMA_TOKEN_SERVER_NAME" -o ! "$CITI_BMA_TOKEN_NODE_NAME"]
   then
      echo -e "ERROR: CITI_BMA_TOKEN_CLUSTER_NAME or CITI_BMA_TOKEN_SERVER_NAME/CITI_BMA_TOKEN_NODE_NAME variable needs to be set."
      exit 1
   fi
fi

export PATH=$CITI_EMT_WAS_HOME/bin:$PATH
export EMT_WASCE_HOME=$CITI_EMT_WAS_HOME

if [ "$CITI_BMA_TOKEN_CLUSTER_NAME" ]
then
   clusterName="$CITI_BMA_TOKEN_CLUSTER_NAME"
else
   clusterName="$CITI_BMA_TOKEN_SERVER_NAME,$CITI_BMA_TOKEN_NODE_NAME"
fi

if [[ "$CITI_WAS_START_STOP_ACTION" =~ "start" ]]
then
	echo "Running Command..$CITI_EMT_WAS_HOME/bin/emt -Action ExecutePyScript -CellName $CITI_BMA_TOKEN_CELL_NAME -DMGRFunctionalId $CITI_WAS_ADMIN_USER -ScriptLocation ./citi_wasnd_cluster_start.py -ScriptArguments $clusterName"
	result=`$CITI_EMT_WAS_HOME/bin/emt -Action ExecutePyScript -CellName $CITI_BMA_TOKEN_CELL_NAME -DMGRFunctionalId $CITI_WAS_ADMIN_USER -ScriptLocation $VL_CHANNEL_ROOT/citi_wasnd_cluster_start.py -ScriptArguments "$clusterName" 2>&1`
else
	echo "Running Command..$CITI_EMT_WAS_HOME/bin/emt -Action ExecutePyScript -CellName $CITI_BMA_TOKEN_CELL_NAME -DMGRFunctionalId $CITI_WAS_ADMIN_USER -ScriptLocation ./citi_wasnd_cluster_stop.py -ScriptArguments $clusterName"
	result=`$CITI_EMT_WAS_HOME/bin/emt -Action ExecutePyScript -CellName $CITI_BMA_TOKEN_CELL_NAME -DMGRFunctionalId $CITI_WAS_ADMIN_USER -ScriptLocation $VL_CHANNEL_ROOT/citi_wasnd_cluster_stop.py -ScriptArguments "$clusterName" 2>&1`
fi


echo "$result"
if [[ "$result" =~ "[ERROR]" ]]
then
   echo "ERROR: Found Error in output from EMT command."
   exit 1
fi

DATE2=`date +"%m/%d/%y"`
TIME2=`date +"%H:%M:%S"`
echo "INFO: End of Deployment execution on Server $VL_DISPATCH_TARGET_HOST"
echo "INFO: Deployment on Server End Time: $DATE2 $TIME2"
echo -e "\n##############################################################"
echo -e "##"
echo -e "##############################################################\n\n\n"


