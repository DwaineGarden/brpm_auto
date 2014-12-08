#############################################################################
# Copyright @ 2012-2014 BMC Software, Inc.                                  #
# This script is supplied as a template for performing the defined actions  #
# via the BMC Release Package and Deployment. This script is written        #
# to perform in most environments but may require changes to work correctly #
# in your specific environment.                                             #
#############################################################################
#---------------------- svnStaging_shell -----------------------#
# Description: Pulls artifacts from a subversion server to a local RPM repository
#  must have a staging server either in the 
#---------------------- Arguments --------------------------#
###
# Svn Target:
#   name: Svn path to checkout
#   type: in-text
#   position: A1:F1
# Svn Revision:
#   name: revision to checkout
#   type: in-text
#   position: A2:F2
# output_status:
#   name: status
#   type: out-text
#   position: A1:F1
###

#---------------------- Integration Header (do not modify) -----------------------#
#=== General Integration Server: SVN ===#
# [integration_id=6]
SS_integration_dns = "https://svn.nam.nsroot.net:9050"
SS_integration_username = "rlm_user"
SS_integration_password = "-private-"
SS_integration_details = "svn_path: /export/opt/svn/1.7.5/opt/CollabNet_Subversion
svn_options: --no-auth-cache --trust-server-cert --force --non-interactive
env_variables: LD_LIBRARY_PATH=/export/opt/svn/1.7.5/opt/CollabNet_Subversion/lib"
SS_integration_password_enc = "__SS__Cj1JWFp6VjNYdHhtYw=="
#=== End ===#

#=> ------------- IMPORTANT ------------------- <=#
#- This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest
require 'erb'
require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")
rpm_load_module("nsh", "dispatch_nsh")

# Note action script will be processed as ERB!
#----------------- HERE IS THE ACTION SCRIPT -----------------------#
script =<<-END
#!/bin/bash
# Action for checking out from SubVersion
#
# this script should perform the necessary actions to deposit files into
# the directory specified by the RPM_POST_PATH environment variable.
#
# Create Environment Variables
<% transfer_properties.each do |key, val| %>
<%= key + '="' + val + '"' %>
<% end %>

#
# create the directory, it does not exist at startup time. 
#
if [ ! -d "$RPM_POST_PATH" ]; then  
  mkdir $RPM_POST_PATH
fi
#
# anything deposited into RPM_POST_PATH will be transferred back to the local repo 
# console when this script completes.
#
# sdunbar BMC - updated to add  --trust-server-cert arg
# sdunbar BMC - updated to add path to svn and lib folder

#CITI_SVN_PATH=/xenv/svn-c/X/1.7.4l_64/bin
#export LD_LIBRARY_PATH=/xenv/svn-c/X/1.7.4l_64/lib
#env var required for SVN
export LD_LIBRARY_PATH=$CITI_SVN_PATH/lib

echo "SVN_LOGIN is $SVN_LOGIN"
echo "SVN_TARGET is $SVN_TARGET"

if [ -z "$SVN_OPTIONS" ]; then
  SVN_OPTIONS="--no-auth-cache --non-interactive --trust-server-cert --force"
fi

cd $RPM_POST_PATH
if [ -z "$SVN_REV" ]; then  
  $CITI_SVN_PATH/bin/svn export $SVN_LOGIN $SVN_OPTIONS $SVN_TARGET $RPM_POST_PATH
else
  echo $CITI_SVN_PATH/bin/svn export $SVN_LOGIN $SVN_OPTIONS -r $SVN_REV $SVN_TARGET $RPM_POST_PATH
fi

cd ..

# verify some files are there
TEST=`find $RPM_POST_PATH -type d -empty`

if [ ! -z "$TEST" ]; then
    echo "No files fetched!" 1>&2
    exit 1
fi

exit 0

END
#---------------------- Begin Ruby Shell Wrapper ----------------------------#

# Properties needed
# CITI_SVN_PATH, RPM_POST_PATH, SVN_REV, SVN_TARGET, SVN_OPTIONS, SVN_LOGIN, SVN_URL
nsh_path = "#{defined?(NSH_PATH) ? NSH_PATH : "/opt/bmc/blade8.5"}/NSH"
@srun = DispatchNSH.new(nsh_path, @params)

#---------------------- Methods ----------------------------#
def make_credential(user, password)
  credential = ""
  credential = " --username #{user} --password #{password}" if password.to_s != ""
end

#---------------------- Variables --------------------------#
@rpm.private_password(decrypt_string_with_prefix(SS_integration_password_enc))
integration_details = get_integration_details(SS_integration_details)
version = @p.get("step_version")    
version = "#{@p.get("SS_request_number")}_#{@rpm.precision_timestamp}" if version == ""
version_url = @p.get("step_version_artifact_url", nil)
brpm_hostname = @p.SS_base_url.gsub(/^.*\:\/\//, "").gsub(/\:\d.*/, "")
svn_target = @p.get("Svn Target", @p.svn_target)
svn_revision = @p.get("Svn Revision", @p.svn_revision)
staging_path = @rpm.get_staging_dir(version, true)
svn_staging_server = "localhost"
svn_local_path = staging_path # "/opt/bmc/citi/deploy_test_svn"

#---------------------- Main Body --------------------------#
if svn_target == "" && version_url.nil?
  raise "Command_Failed: no svn target to checkout"
elsif !version_url.nil?
  svn_url = version_url
  svn_url = "#{SS_integration_dns}#{version_url}" if !version_url.include?("://")
else
  svn_url = svn_target
  svn_url = "#{SS_integration_dns}#{svn_target}" if !svn_target.include?("://")
end
url_parts = URI.parse(svn_url)
#svn_target = url_parts.path
#@rpm.private_password[url_parts.password] unless url_parts.password.nil?
transfer_properties = {
  "CITI_SVN_PATH" => integration_details["svn_path"], 
  "RPM_POST_PATH" => svn_local_path,
  "SVN_TARGET" => svn_target,
  "SVN_OPTIONS" => integration_details["svn_options"],
  "SVN_LOGIN" => make_credential(SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc))
}
transfer_properties["SVN_REV"] = svn_revision if svn_revision != ""
action_txt = ERB.new(script).result(binding)
@rpm.message_box "Copying Files to Staging via Subversion"
@rpm.log "\t StagingPath: #{staging_path}"
@rpm.log "\t SubversionURL: #{svn_target}"    
script_file = @srun.make_temp_file(action_txt)
FileUtils.cd(staging_path, :verbose => true)
cmd_result = @srun.execute_shell("/bin/bash #{script_file}")
@rpm.log "Subversion Results"
@rpm.log(@srun.display_result(cmd_result))
result = @srun.package_staged_files(staging_path, version)
@rpm.log "SRUN Result: #{result.inspect}"
raise "Command_Failed: no files received from svn" if result["instance_path"].start_with?("ERROR")
@p.assign_local_param("instance_#{@p.SS_component}", result)
@p.assign_local_param("instance_#{@p.SS_component}_svn_url", svn_target)
@rpm.log "Saved in JSON Params: #{"instance_#{@p.SS_component}"}"
@p.save_local_params
pack_response("output_status", "Successfully packaged - #{File.basename(result["instance_path"])}")

