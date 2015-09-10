# ---------- f2_addTeamsGroupsAndRoles
#  Adds a team for every application
# Patterns
#  For an application : 1183_LOPR
#  For a team         : 1183_LOPR
#  Groups: 
#    1183_LOPR_Approver => RLM_App_Approver
#    1183_LOPR_Coordinator => RLM_App_Coordinator
#    1183_LOPR_Developer => RLM_App_Developer
#    1183_LOPR_OpsDeployer => RLM_App_OpsDeployer
#    1183_LOPR_User => RLM_App_Approver
require 'rubygems'
require 'fileutils'
require 'yaml'
require 'active_support'
require 'active_support/core_ext'

# Key variables
@groups = ["%APP%_Approver", "%APP%_Coordinator", "%APP%_Developer", "%APP%_OpsDeployer", "%APP%_User"]

#  These roles must EXIST in the app already
@role_lookup = {"RLM_App_Approver" => "user", "RLM_App_Coordinator" => "deployment_coordinator", "RLM_App_Developer" => "requestor", "RLM_App_OpsDeployer" => "deployer" , "Not Visible" => "User"}

#  Users export file
users_yml = "/Users/brady/Documents/dev_rpm/brpm_auto/brpm_auto/draft/user_roles.yml"

standalone = false # set to false if running in a BRPM automation

if standalone
  # Mock the BRPM Automation
  rlm_base_path = "/opt/bmc/rlm"
  script_support = "#{rlm_base_path}/releases/current/RPM/lib/script_support"
  persist = "#{rlm_base_path}/persist/automation_lib"
  FileUtils.cd script_support, :verbose => true
  require "#{script_support}/ssh_script_header"
  input_file = "#{rlm_base_path}/automation_results/request/Utility/21675/step_34584/scriptinput_11260_1416331563.txt"
  script_params = params = load_input_params(input_file)
  require "#{persist}/automation_lib/brpm_framework.rb"
end

Token = "95445426b039db413be9469b11a6568c55a7fb87"


#------------------------- Methods -----------------------------#
def name_filter(model, item_name)
  name_filter = ""
  name_filter = "filters[name]=#{item_name}" if item_name.length > 2
  add_filter = ""
  add_filter = "filters[include_except]=requests,steps,installed_components,tickets,users" if model == "apps"
  joiner = add_filter.length > 0 && name_filter.length > 0 ? "&" : ""
  result = @rest.get(model, nil, {"filters" => "#{name_filter}#{joiner}#{add_filter}", "suppress_errors" => true})
  return result
end

def create_team(team_name)
  team_data = {"team" => {"name" => team_name}}
  result = @rest.create("teams", team_data)
end

def update_team(team_id, app_ids, group_ids)
  team_data = {"team" => {"app_ids" => app_ids, "group_ids" => group_ids}}
  result = @rest.update("teams", team_id, team_data)
end

def create_groups(team_name, group_ids = [])
  group_names = @groups.map{|l| l.gsub("%APP%", team_name)}
  groups = {}
  group_names.each do |group_name|
    role_names = [group_name.gsub("#{team_name}_", "").singularize.titleize, "User", "not_visible"]
    result = name_filter("groups", group_name)
    if result["status"] == "ERROR"
      @rpm.log "Group: #{group_name} not found, creating"
      group_data = {"group" => {"name" => group_name}}
      result = @rest.create("groups", group_data)
      group = result["data"]
    else
      group = result["data"].first
      @rpm.log "Group: #{group_name} exists"
    end
    groups[group_name] = group["id"]
    role_ids = get_group_roles(group_name,team_name)
    update_group_roles(group["id"], role_ids)
  end
  groups
end

def get_group_roles(group_name, app_name)
  # 1183_LOPR_Coordinator => RLM_App_Coordinator
  role = group_name.gsub(app_name,"RLM_App")
  [@role_ids[role], @role_ids["Not Visible"]]
end

def update_group_roles(group_id, role_ids)
  group_data = {"group" => {"role_ids" => role_ids}}
  result = @rest.update("groups", group_id, group_data)
end

def get_role_ids
  @role_ids = {}
  roles_found = []
  result = @rest.get("roles")
  result["data"].each do |role|
    if @role_lookup.keys.include?(role["name"])
      @role_ids[role["name"]] = role["id"]
      roles_found << role["name"]
    end
  end
  raise "Error - some roles are missing: need: #{@role_lookup.keys.join(",")} | Found: #{roles_found.join(",")}" if roles_found.size != @role_lookup.size
  @role_ids
end
 
#---------------------------------------------------------------#
#    MAIN ROUTINE
#---------------------------------------------------------------#
@rest = BrpmRest.new(url, params, {"token" => Token})
result_set = {"teams" => {}, "groups" => {}, "users" => {}}
@rpm.message_box "Building Teams from App Names", "title"
@apps = name_filter("apps", "")
@rpm.log "Getting existing teams"
result = @rest.get("teams")
@teams = result["data"]
team_names = @teams.map{|k| k["name"] }
@rpm.log "Opening users export from 4.4"
@rpm.log users_yml
user_data = YAML.load_file(users_yml)
get_role_ids
cnt = 0
@apps["data"].each do |app|
  group_ids = []
  app_ids = []
  @cur_app = app["name"]
  result_set[@cur_app] = {"id" => app["id"]}
  @rpm.message_box "#{cnt}) App: #{@cur_app}", "title"
  ipos = team_names.index(@cur_app)
  #next if cnt > 7
  if ipos.nil?
    @rpm.log "Team: #{@cur_app} not found, creating"
    result = create_team(@cur_app)
    team = result["data"]
  else
    team = @teams[ipos]
    @rpm.log "Team: #{@cur_app} exists"
    team["apps"].each{|l| app_ids << l["id"] }
    team["groups"].each{|l| group_ids << l["id"] }
  end
  result = create_groups(@cur_app)
  app_ids << app["id"] unless app_ids.include?(app["id"])
  group_ids = (group_ids + result.values).uniq
  result_set["teams"][team["name"]] = {"id" => team["id"], "app_ids" => app_ids, "groups" => result}
  result_set["groups"].merge(result)
  result = update_team(team["id"], app_ids, group_ids)
  cnt += 1
end

@rpm.message_box "Processing Users", "title"
user_data.each do |user|
  teams = []
  team_ids = []
  new_role = ""
  group_names = []
  result = @rest.get("users", user["id"], {"suppress_errors" => true})
  if result["status"] != "success"
    @rpm.log "#{user["login"]} - Not found"
    next
  end
  @rpm.log "#-------------------------#\nUser: #{result["data"]["login"]}"
  group_ids = result["data"]["groups"].map{|k| k["id"] }
  role = user["roles"].first
  @role_lookup.each{|k,v| new_role = k if role == v }
  @rpm.log "\tPrimary Group/Role: #{new_role}"
  user["teams"].split(",").each do |it|
    team = it.split("_|_")[0]
    team_id = it.split("_|_")[1]
    @teams[team_names.index(team)]["apps"].each do |app|
      group_names << "#{app["name"]}_#{new_role}"
      @rpm.log "\tGroup: #{app["name"]}_#{new_role}"
    end
  end
  group_names.each{|g| group_ids << result_set["groups"][g] }
  result_set["users"][result["data"]["login"]] = {"id" => result["data"]["id"], "groups" => group_names}
  user_info = {"user" => {"group_ids" => group_ids.uniq.delete_if{|el| el.nil? }}}
  result = @rest.update("users", user["id"], user_info)
end

@rpm.message_box "Summary", "title"
@rpm.message_box "Primary Roles"
@rpm.log @role_lookup.keys.join("\n")


@rpm.message_box "App Management Teams"
result_set["teams"].each do |team, details|
  @rpm.log "#{team}: #{details["groups"].keys.join(", ")}"
end

@rpm.message_box "User Group Assignment"
result_set["users"].each do |user, details|
  @rpm.log "#{user}: #{details["groups"].join(", ")}"
end
