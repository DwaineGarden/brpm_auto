#!/bin/bash
###
#
# PATH_TO_FILE:
#   name: Source file path to expand
#   position: A1:F1
#   type: in-text
#
# TARGET_PATH:
#   name: Target file path to append to
#   position: A2:F2
#   type: in-text
# ZIP_PATH:
#   name: location of unzip (include the executable)
#   position: A3:F3
#   type: in-text
#
###

#
# ExecuteCommand
#
#	Executes COMMAND_TO_EXECUTE in TARGET_PATH using dos batch
# 


echo "Unzipping $PATH_TO_FILE"
echo "IN $TARGET_PATH"
cd $TARGET_PATH
if [[ $ZIP_PATH -ne "" ]]
  zip_path = $ZIP_PATH
then
  zip_path = "unzip"
fi
$zip_path $PATH_TO_FILE

