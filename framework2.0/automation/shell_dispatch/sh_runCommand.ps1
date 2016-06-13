#![.ps1]powershell.exe -ExecutionPolicy Unrestricted -File
#
# cmd_runCommand(windows)
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

$script:ErrorActionPreference = "Continue"

$cmd_to_exec = $env:COMMAND_TO_EXECUTE
$cmd_to_exec1 = $env:COMMAND_TO_EXECUTE1
$cmd_to_exec2 = $env:COMMAND_TO_EXECUTE2
$cmd_to_exec3 = $env:COMMAND_TO_EXECUTE3

if ($env:TARGET_PATH.Length -gt 1) {
  cd $env:TARGET_PATH
}
Write-host "1-Executing $cmd_to_exec"
CMD /c $cmd_to_exec
if ($cmd_to_exec1.Length -gt 2 ) {
  Write-host "2-Executing $cmd_to_exec1"
  CMD /c $cmd_to_exec1
  }
if ($cmd_to_exec2.Length -gt 2 ) {
  Write-host "3-Executing $cmd_to_exec2"
  CMD /c $cmd_to_exec2
  }
if ($cmd_to_exec3.Length -gt 2 ) {
  Write-host "4-Executing $cmd_to_exec3"
  CMD /c $cmd_to_exec3
  }

