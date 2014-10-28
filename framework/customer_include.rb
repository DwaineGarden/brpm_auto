# = BRPM Automation Framework
# == Customer Include Automation
#    BMC Software - BJB 9/16/2014
# ===== Use this routine to override and provide global methods for all your automation

# set your own automation token
Token = "a56d64cbcffcce91d306670489fa4cf51b53316c" #decrypt_string_with_prefix(@params["SS_api_token"])
NSH_PATH = "/opt/bmc/bladelogic/NSH"
# Change this to set BAA base path 
BAA_BASE_PATH = "/opt/bmc/bladelogic"

# This sets the behavior of the framework foreach of the action languages
ACTION_PLATFORMS = {
    "batch" => {"transport" => "nsh", "platform" => "windows", "language" => "batch", "comment_char" => "REM", "env_char" => "set ", "lb" => "\r\n", "ext" => "bat"},
    "powershell" => {"transport" => "nsh", "platform" => "windows", "language" => "powershell", "comment_char" => "#", "env_char" => "$env:", "lb" => "\r\n", "ext" => "ps1"},
    "bash|shell" => {"transport" => "nsh", "platform" => "linux", "language" => "bash", "comment_char" => "#", "env_char" => "", "lb" => "\n", "ext" => "sh"},
    "ssh|capistrano" => {"transport" => "ssh", "platform" => "linux", "language" => "ruby", "comment_char" => "#", "env_char" => "", "lb" => "\n", "ext" => "rb"},
    "nsh" => {"transport" => "none", "platform" => "linux", "language" => "nsh", "comment_char" => "#", "env_char" => "", "lb" => "\n", "ext" => "nsh"}
}

#Execution Wrappers are for script types that require a command shell intermediate script to execute
EXECUTION_WRAPPERS = {
  "powershell" => "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -ExecutionPolicy Unrestricted -File <script_file>\r\n"
}
# Place your own global constants
DATA_CENTER_NAMES = ["HOU", "LEX", "PUNE"]


