#!/bin/bash
###
#
# SERVICE_TERM:
#   name: Term to grep in the services output
#   position: A1:C1
#   type: in-text
#
# SUCCESS_TERM:
#   name: Term to match in the grep output
#   position: A2:C2
#   type: in-text
###

#
# processCheck
#
#	Runs a ps -ef and greps for the SERVICE_TERM
# 

RES=`ps -ef | grep ${SERVICE_TERM}`
echo "Running: ps -ef | grep $SERVICE_TERM"
echo $RES
size=${#RES}
echo "Answer length: ${size}"
if [[ $RES == *"${SUCCESS_TERM}"* ]]; then
  echo "(Success) Found term: ${SUCCESS_TERM}"
  exit 0
fi
exit 1

