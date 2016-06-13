#
# sh_runCommand(linux)
#
#	Executes COMMAND_TO_EXECUTE in TARGET_PATH using bash
# 

###
#
# COMMAND_TO_EXECUTE:
#   name: First line of commands to execute
#   position: A1:F1
#   type: in-text
#
# COMMAND_TO_EXECUTE1:
#   name: Second line of commands to execute
#   position: A2:F2
#   type: in-text
#
# COMMAND_TO_EXECUTE2:
#   name: Third line of commands to execute
#   position: A3:F3
#   type: in-text
#
# COMMAND_TO_EXECUTE3:
#   name: Fourth line of commands to execute
#   position: A4:F4
#   type: in-text
#
# TARGET_PATH:
#   name: Target file path to append to
#   position: A5:F5
#   type: in-text
#
###

if [[ $TARGET_PATH -ne "" ]]; then
  cd $TARGET_PATH
fi
echo "1-Executing $COMMAND_TO_EXECUTE"
bash -c "$COMMAND_TO_EXECUTE"
if [[ ${#COMMAND_TO_EXECUTE1} -gt 2 ]]; then
  echo "2-Executing $COMMAND_TO_EXECUTE1"
  bash -c "$COMMAND_TO_EXECUTE1"
fi
if [[ ${#COMMAND_TO_EXECUTE2} -gt 2 ]]; then
  echo "3-Executing $COMMAND_TO_EXECUTE2"
  bash -c "$COMMAND_TO_EXECUTE2"
fi
if [[ ${#COMMAND_TO_EXECUTE3} -gt 2 ]]; then
  echo "4-Executing $COMMAND_TO_EXECUTE3"
  bash -c "$COMMAND_TO_EXECUTE3"
fi