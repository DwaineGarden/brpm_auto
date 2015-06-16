# ---------- f2_exportUserRoles
#  Exports users and roles to yaml
#  Do this on your RPM4.4 database before upgrading
require 'fileutils'
require 'yaml'

#  Users export file
users_yml = "/Users/brady/Documents/dev_rpm/brpm_auto/brpm_auto/draft/user_roles.yml"
#Token = "95445426b039db413be9469b11a6568c55a7fb87"

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
if true
  rlm_base_path = "/Users/brady/Documents/dev_rpm/brpm_brady/brpm/branches/rpm-sustaining/Portal"
  #rlm_base_path = "/opt/bmc/rlm4"
  script_support = "#{rlm_base_path}/lib/script_support"
  persist = "/Users/brady/Documents/dev_rpm/bmc_devops/continuous_delivery/BRPM/framework"
  FileUtils.cd script_support, :verbose => true
  require "#{script_support}/ssh_script_header"
  input_file = "#{rlm_base_path}/public/automation_results/request/Sales-Billing/1304/step_3722/sshinput_6_1433379304.txt"
  script_params = params = load_input_params(input_file)
  require "#{persist}/brpm_framework.rb"
  url = "http://10.20.12.23:8088/brpm"
end
Token = "95445426b039db413be9469b11a6568c55a7fb87"
url = "http://kunalrh5desk.bmc.com:4490/brpm"

#---------------------------------------------------------------#
#    MAIN ROUTINE
#---------------------------------------------------------------#
@rest = BrpmRest.new(url, params, {"token" => Token})

users = []
result = @rest.get("users")
result["data"].each{|l| users << {"id" => l["id"], "login" => l["login"], "roles" => l["roles"], "email" => l["email"], "active" => l["active"], "teams" => l["teams"].map{|k| "#{k["name"]}_|_#{k["id"]}" }.join(',')}}

fil = File.open(users_yml, "w")
fil.puts users.to_yaml
fil.close

