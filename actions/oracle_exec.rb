################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- Action Name -----------------------#
# Description: Oracle SQLPlus exec
#   You can specify a path to a single script or directory
#   all files in the directory will be transported to the target server
#   and processed in alphabetical sequence
#   If you upload a script, that will be transported and executed
#   Set properties for ARG_ORACLE_HOME, ARG_ORACLE_USERNAME, ARG_ORACLE_PASSWORD, ARG_ORACLE_SID

#---------------------- Arguments --------------------------#
###
# scripts_to_execute:
#   name: script on file system to execute (NSH path)
#   position: A1:F1
#   type: in-text
# script_file_to_execute:
#   name: Upload a sql script
#   position: A2:C2
#   type: in-file
###

#---------------------- Declarations -----------------------#
#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
# Properties will automatically be pushed to env variables if prefixed with the ARG_PREFIX

# Note: automation category suffix must be in the ACTION_PLATFORMS definition in the customer_include.rb file
automation_category = "Oracle_bash"

# Note action script will be processed as ERB!
#----------------- HERE IS THE ACTION SCRIPT -----------------------#
script =<<-END
#
# Action to run sql file via Oracle's sqlplus
#
# REQUIRED VARIABLES
#   ORACLE_HOME
#   ORACLE_USERNAME
#   ORACLE_PASSWORD
#   ORACLE_SID

# NOTE:  Returning proper exit codes from the provided sql file must be done to
#   ensure that the action will exit with success or failure of the sql commands
#   being run.  For example:

# WHENEVER SQLERROR EXIT SQL.SQLCODE
#   begin
#     SELECT COLUMN_DOES_NOT_EXIST FROM DUAL;
#   END;
export ORACLE_HOME

SQLPLUS="sqlplus"
if [ ! -z "$ORACLE_HOME" ]
then
    SQLPLUS="$ORACLE_HOME/bin/sqlplus"
fi

TMPFILE=file$RANDOM.sql
ln -s $RPM_PAYLOAD $TMPFILE


echo "echo quit | $SQLPLUS -L -s $ORACLE_USERNAME/-------@$ORACLE_SID @$TMPFILE"
echo quit | (($SQLPLUS -L -s $ORACLE_USERNAME/$ORACLE_PASSWORD@$ORACLE_SID @$TMPFILE) && unlink $TMPFILE)

exit $?
END


#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
arg_prefix = "ENV_"
failure = "ERROR at line"
sql_uploaded_file = @p.script_file_to_execute
sql_script_path = @p.scripts_to_execute
max_time = @p.get("step_estimate", "300").to_i

#---------------------- Main Script --------------------------#
# The source for sql files may be either an uploaded file or a passed path to a file or directory
#  The files will be assembled and executed in alphabetical order
raise "Command_Failed: No sql scripts to execute" if sql_uploaded_file == "" && sql_script_path == ""
sql_files = []
sql_files << sql_uploaded_file if sql_uploaded_file != ""
if sql_script_path != ""
  if File.directory?(sql_script_path)
    Dir.entries(sql_script_path).reject{|l| l.start_with?(".") }.sort.each{|l| sql_files << File.join(sql_script_path, l) }
  else
    sql_files << sql_script_path
  end
end
# This will execute the action
#  execution targets the selected servers on the step, but can be overridden in options
options = {} # Options can take several keys for overrides
results = []
@action = Action.new(@p,{"automation_category" => automation_category, "property_filter" => arg_prefix, "timeout" => max_time, "debug" => false})
sql_files.each do |sql_file|
  options["payload"] = sql_file
  results << @action.run!(script, options)
end
results.each do |result|
  @auto.log @action.display_result(result)
end
@auto.message_box "Analyzing Results"
results.each_with_index do |result, idx|
  msg = "#{sql_files[idx]} "
  if result["stdout"].include?(failure)
    @auto.log "\t#{msg} - Command_Failed: found error term: [#{failure}]" if result["stdout"].include?(failure)
  else
    @auto.log "\t#{msg} - SUCCESS"
  end
end


params["direct_execute"] = "yes"
