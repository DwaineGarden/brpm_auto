
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
#
###

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

$in_path = $env:PATH_TO_FILE

if ($env:TARGET_PATH.Length -gt 1) {
  $out_path = $env:TARGET_PATH
} else {
  $out_path = $in_path
}
Write-host "Unzipping File: $in_path"
Write-host "Target: $out_path"
unzip $in_path $out_path