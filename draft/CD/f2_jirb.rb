require 'yaml'
require 'json'
#FRAMEWORK_DIR = "C:/BMC/persist/automation_libs"
FRAMEWORK_DIR = "/opt/bmc/persist/automation_lib"
base_path = "/opt/bmc/RLM"
#input_file = "#{base_path}/automation_results/request/ROMS/14289/step_157935/scriptinput_174_1430847109.txt"
#input_file = "/opt/bmc/RLM/automation_results/request/RLM_CD_Regression/11322/step_10854/scriptinput_10023_1431115891.txt"
input_file = "/opt/bmc/persist/automation_results/request/BRPM/1003/step_17/scriptinput_31_1432315743.txt"
@params = YAML.load(File.open(input_file).read)
require "#{FRAMEWORK_DIR}/brpm_framework"
#nsh_cmd = "ls //clm-aus-003365.bmc.com/c/program\\ files/bmc\\ software/rlm/server/jboss/standalone/log/server.log"
def nsh_cmd(cmd)
  script_file = @transport.make_temp_file(cmd)
  result = @transport.execute_script(script_file, {"transfer_properties" => {}})
end
@postgres_path = "C:\\Program Files\\PostgreSQL\\9.4"
postgres_admin_username = "postgres"
postgres_admin_password ="bmcAdm1n"
postgres_username = "rlm_user"
postgres_password = "bmcAdm1n"
install_database = "rpm_install_db"
customer_database = "rpm_customer_db"
