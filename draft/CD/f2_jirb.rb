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
nsh_cmd = "ls //clm-aus-003365.bmc.com/c/program\\ files/bmc\\ software/rlm/server/jboss/standalone/log/server.log"
