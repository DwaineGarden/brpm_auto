#############################################################################
# Copyright @ 2012-2014 BMC Software, Inc.                                  #
# This script is supplied as a template for performing the defined actions  #
# via the BMC Release Package and Deployment. This script is written        #
# to perform in most environments but may require changes to work correctly #
# in your specific environment.                                             #
#############################################################################
#---------------------- citiOracleExecute_shell -----------------------#
# Description: Executes all files in a directory via oracle sqlplus
#  The path to the deployed files on the oracle host should be passed in the json params
#   or in the arguments 

#---------------------- Arguments --------------------------#
###
# Oracle Scripts Path:
#   name: path to oracle scripts
#   type: in-text
#   position: A1:F1
###

#---------------------- Integration Header (do not modify) -----------------------#
#=== General Integration Server: OracleEng ===#
# [integration_id=10140]
SS_integration_dns = "vm-2a31-a358"
SS_integration_username = "rlmadmin"
SS_integration_password = "-private-"
SS_integration_details = "oracle_home: /opt/optware/oracle/product/11.2.0.2
oracle_sid: cloudapp"
SS_integration_password_enc = "__SS__Ck54a1UwNFdhdFJXUQ=="
#=== End ===#

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require 'erb'
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
rpm_load_module("nsh", "dispatch_nsh")

# Note action script will be processed as ERB!
#----------------- HERE IS THE ACTION SCRIPT -----------------------#
script = <<-END
#!/bin/sh
#
# Action to run sql file via Oracle's sqlplus
#
# REQUIRED VARIABLES
#   CITI_ORACLE_HOME
#   CITI_ORACLE_USERNAME
#   CITI_ORACLE_PASSWORD
#   CITI_ORACLE_SID
#   CITI_ORACLE_BASEPATH
#   RPM_CHANNEL_ROOT

# Create Environment Variables
<% transfer_properties.each do |key, val| %>
<%= key + '="' + val + '"' %>
<% end %>

# NOTE:  Returning proper exit codes from the provided sql file must be done to
#   ensure that the action will exit with success or failure of the sql commands
#   being run.  For example:

# WHENEVER SQLERROR EXIT SQL.SQLCODE
#   begin
#     SELECT COLUMN_DOES_NOT_EXIST FROM DUAL;
#   END;

fatal() {
  echo "$*"
  exit 1
}

echo -e "\n\n\n#############################################################"
echo -e "##"
echo -e "#############################################################\n"
DATE1=`date +"%m/%d/%y"`
TIME1=`date +"%H:%M:%S"`
echo "INFO: Start of Deployment execution"

if [[ "${RPM_CHANNEL_ROOT}" == "/" ]]; then
  fatal "ERROR: RPM_CHANNEL_ROOT cannot be '/'"
fi

SQLPLUS="sqlplus"
export ORACLE_HOME=$CITI_ORACLE_HOME
echo "ORACLE_HOME=$ORACLE_HOME"
echo "CITI_ORACLE_SID=$CITI_ORACLE_SID"
echo "CITI_ORACLE_USERNAME=$CITI_ORACLE_USERNAME"
echo "CITI_ORACLE_PASSWORD=$CITI_ORACLE_PASSWORD"
echo "RPM_CHANNEL_ROOT=$RPM_CHANNEL_ROOT"
STG_DIR="${RPM_CHANNEL_ROOT}"
if [ ! -z "$CITI_ORACLE_HOME" ]
then
    SQLPLUS="$CITI_ORACLE_HOME/bin/sqlplus"
fi
echo "SQLPLUS=$SQLPLUS"
echo "INFO: Staging Directory: $STG_DIR"

if [[ ! -d ${STG_DIR} ]]; then
  fatal "The directory $STG_DIR not found"
fi

for SQL_SCRIPT in `ls ${STG_DIR}/*.sql | sort -n`
do
  echo "$SQLPLUS -L -s USER:${CITI_ORACLE_USERNAME} SID:${CITI_ORACLE_SID} @${SQL_SCRIPT}"
  #echo quit | $SQLPLUS -L -s ${CITI_ORACLE_USERNAME}/${CITI_ORACLE_PASSWORD}@${CITI_ORACLE_SID} @${SQL_SCRIPT}
        if [[ $? -ne 0 ]]; then
    if [ -d "${STG_DIR}" ] && [ "${VL_PROCESS_ID}" != "" ]; then
          rm -rf "${STG_DIR}"
      fi
                fatal "Error: Failed to execute sql file - ${SQL_SCRIPT}"
        fi
done

echo -e "##############################################################\n\n\n"
END
#---------------------- Begin Ruby Shell Wrapper ----------------------------#

# Properties needed
#  CITI_ORACLE_HOME, CITI_ORACLE_USERNAME, CITI_ORACLE_PASSWORD, CITI_ORACLE_SID, RPM_CHANNEL_ROOT, RPM_CONTENT_PATH
nsh_path = "#{defined?(NSH_PATH) ? NSH_PATH : "/opt/bmc/blade8.5"}/NSH"
@srun = DispatchNSH.new(nsh_path, @params)

#---------------------- Methods ----------------------------#

#---------------------- Variables --------------------------#
integration_details = get_integration_details(SS_integration_details)
version = @p.get("step_version")    
version = "#{@p.get("SS_request_number")}_#{@rpm.precision_timestamp}" if version == ""
version_url = @p.get("step_version_artifact_url", nil)
brpm_hostname = @p.SS_base_url.gsub(/^.*\:\/\//, "").gsub(/\:\d.*/, "")
scripts_path = @p.get("Oracle Scripts Path", @p.oracle_scripts_path)
staging_info = @p.required("instance_#{@p.SS_component}")
oracle_svn_url = @p.get("instance_#{@p.SS_component}_svn_url")
base_path = oracle_svn_url.split("/")[-1] # Usually checks out to the last item in the path

#---------------------- Main Body --------------------------#

#@rpm.private_password[url_parts.password] unless url_parts.password.nil?
transfer_properties = {
  "CITI_ORACLE_HOME" => integration_details["oracle_home"], 
  "CITI_ORACLE_USERNAME" => SS_integration_username,
  "CITI_ORACLE_PASSWORD" => decrypt_string_with_prefix(SS_integration_password_enc),
  "CITI_ORACLE_SID" => integration_details["oracle_sid"],
  "CITI_ORACLE_BASEPATH" => base_path
}
# Note RPM_CHANNEL_ROOT will be set in the run script routine
action_txt = ERB.new(script).result(binding)
@rpm.message_box "Executing Oracle Script(s)"
@rpm.log "\t StagingPath: #{staging_info["instance_path"]}"
script_file = @srun.make_temp_file(action_txt)
result = @srun.execute_script(script_file)
@rpm.log "SRUN Result: #{result.inspect}"
#pack_response("output_status", "Successfully packaged - #{File.basename(result["instance_path"])}")

params["direct_execute"] = true
