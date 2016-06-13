#![.ps1]powershell.exe -ExecutionPolicy Unrestricted -File

###
#
# SOURCE_PATH:
#   name: Source file path containing text to append
#   position: A1:F1
#   type: in-text
#
# TARGET_PATH:
#   name: Target file path to append to
#   position: A2:F2
#   type: in-text
#
###

#
# Append To File
#
#	Appends SOURCE_PATH file contents to TARGET_PATH file will respect tags if xml or html
#
# Check variables
if (Test-Path $env:SOURCE_PATH ) {
  $source_path = $env:SOURCE_PATH
} else {
	"SOURCE_PATH file does not exist"
	exit 1
}

if (Test-Path $env:TARGET_PATH ) {
  $target_path = $env:TARGET_PATH
} else {
	"TARGET_PATH file does not exist"
	exit 1
}

Write-Host "Appending $target_path to $source_path"
$append = Get-Content $target_path
$con = Get-Content $source_path
$con + "`n" + $append | Set-Content $source_path

