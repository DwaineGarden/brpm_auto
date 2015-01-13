################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_createDemoContent -----------------------#
# Description: Creates some mock content for deployments
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 

#---------------------- Arguments --------------------------#

#---------------------- Methods ----------------------------#
def save_staging_file(file_name, content, set_priv = nil)
  full_path = File.join(@staging, file_name)
  FileUtils.mkdir_p(File.dirname(full_path), :verbose => true) unless File.exist?(File.dirname(full_path))
  fil = File.open(full_path, "w+")
  fil.puts content
  fil.flush
  fil.close
  FileUtils.chmod(set_priv, full_path) unless set_priv.nil?
  full_path
end

def pg_query_script
  rlm_path = @p.SS_automation_results_dir.gsub("automation_results","pgsql")
  db_data = YAML.load(File.open(@p.SS_script_support_dir.gsub("lib/script_support", "config/database.yml")).read)
  db_user = db_data["production"]["username"]
  db_name = db_data["production"]["database"]
  db_port = db_data["production"]["port"]
  script =<<-END
# SQL Exercises for PostgreSQL
Query_file=$1
RLM_path=#{rlm_path}
Db_user=#{db_user}
Db_name=#{db_name}
Db_port=#{db_port}
echo "#-------------------------------------------------#"
echo "#     Performing PostgreSQL Query                 #"
echo "#-------------------------------------------------#"
echo $RLM_path/bin/psql -P pager=off -U $Db_user -p $db_port $Db_name -f $Query_file
$RLM_path/bin/psql -P pager=off -U $Db_user -p $Db_port $Db_name -f $Query_file
END
  save_staging_file(File.join("AppServer", "execute_pg.sh"), script, 0755)
end

#---------------------- Variables --------------------------#
params["direct_execute"] = true #Set for local execution
version = "1.0.0.1"
app_name = "Example"

#---------------------- Main Body --------------------------#
# Create the staging directory
dir_parts = @p.SS_automation_results_dir.split("/")
dname = dir_parts[-2]
base_dir = dir_parts[0..-3].join("/") # should be "/opt/bmc" or "C:/Program Files/BMC Software"
@staging = File.join(base_dir, "rpm_demo", "staging", app_name, version)
@deploy = File.join(base_dir, "rpm_demo", "deploy")
@rpm.message_box "Building content for sample deploy"
@rpm.log "Building staging directories"
FileUtils.mkdir_p(File.join(@staging, "AppServer"), :verbose => true)
FileUtils.mkdir_p(@deploy, :verbose => true)
#Copy files to be used for appserver deploy
@rpm.log "Copying content to staging"
FileUtils.cp_r @p.SS_script_support_path.gsub("script_support", "tasks"), File.join(@staging, "AppServer")
# Now copy/create files for db deploy
@rpm.log "Creating database scripts"
query1 = "select a.name as app, ac.id, c.name from application_components ac inner join apps a on ac.app_id = a.id inner join components c on c.id = ac.component_id"
save_staging_file(File.join("Database", "components.sql"), query1)
query2 = "select r.id, r.name, e.name as environment from requests r inner join environments e on e.id = r.environment_id "
save_staging_file(File.join("Database", "requests.sql"), query2)
# Now create a version tag to support the new content
@rpm.log "Creating version tag to hold demo information"
data = { "name" => version, "artifact_url" => File.join(@staging, "Database"), "find_application" => app_name, "find_component" => "Database", "active" => true}
res = @rest.create("version_tags", data)
@rpm.log res.inspect
data = { "name" => version, "artifact_url" => File.join(@staging, "AppServer"), "find_application" => app_name, "find_component" => "AppServer", "active" => true}
res = @rest.create("version_tags", data)
@rpm.log res.inspect
