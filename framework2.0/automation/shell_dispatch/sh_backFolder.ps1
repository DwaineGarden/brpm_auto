#![.ps1]powershell.exe -ExecutionPolicy Unrestricted -File

###
#
# SOURCE_PATH:
#   name: Source path (folder) to backup
#   position: A1:F1
#   type: in-text
#
# TARGET_PATH:
#   name: Target path to backup to (blank = parent folder)
#   position: A2:F2
#   type: in-text
###

#
# Backup a folder
#
#	Copies SOURCE_PATH folder to TARGET_PATH and appends a timestamp
#
$script:ErrorActionPreference = "Continue"

function convert_nsh_path($nsh_path){
  $reg = [regex]"^\/[A-Z]\/"
  $result = $nsh_path
  if($nsh_path -Match $reg ) {
    $ans = $reg.Match($nsh_path)
	$let = $ans.Captures[0].value.Replace("/","")
	$result = $nsh_path.Replace($ans.Captures[0].value, $let + ":\").Replace("/","\")
  }
  return $result;
}
$source_path = $env:SOURCE_PATH
$source = convert_nsh_path($source_path)
$target = (Get-Item $source ).parent

$last_folder = Split-path (Split-path $source -Parent) -Leaf
# Check variables
if ($env:TARGET_PATH -eq "") {
	"TARGET_PATH environment variable not set using source"
} else {
  $target_path = $env:TARGET_PATH
  $target = convert_nsh_path($target_path) 
}

$target = $target + "\" + $last_folder + "_" + $(get-date -f MM-dd-yyyy_HH_mm_ss)
Write-Host "Copying $source to $target"
Copy-Item $source $target -Recurse
