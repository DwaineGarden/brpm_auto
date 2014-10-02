#  NOTE: this is written in ERB!
script=<<-END
# Important leave the start and end lines here
#---------START_SHELL_SCRIPT----------#

#!/bin/bash
echo #---- Showing Java Procs --------#
ps -ef | grep java
# Note variable substitution in the script
ls -l <%=target_dir %>

#--------END_SHELL_SCRIPT-------------#
END
