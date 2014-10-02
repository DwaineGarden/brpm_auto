#---------------------- nsh_shellExecute -----------------------#
# Description: Execute text variable as a shell script on selected servers
#---------------------- Arguments ------------------------------#
###
# pick a file:
#   name: file picker
#   position: A1:F1
#   type: in-text
###

#----------------------- Declarations ----------------------------#
params["direct_execute"] = true #Set for local execution
require '/home/bbyrd/nsh_classy_alt.rb'

#----------------------- Variables -------------------------------#
# Assign local variables to properties and script arguments
nsh_path = "/opt/bmc/blade8.5/NSH"
target_dir = "/home/bbyrd/logs"
@nsh = NSH.new(nsh_path, params)
#----------------------- Shell Script ----------------------------#
script=<<-END
#---- PASTE THE BODY OF YOUR SHELL SCRIPT HERE ----------#
#!/bin/bash
echo #---- Showing Java Procs --------#
ps -ef | grep java
# Note variable substitution in the script
ls -l #{target_dir}
#--- THE END LINE IS IMPORTANT! --#
END
#----------------------- End of Shell Script ---------------------------------#

#----------------------- Main Routine ----------------------------#
@nsh.nsh_command(script)


