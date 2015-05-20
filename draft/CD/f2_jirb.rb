require 'yaml'
require 'json'
FRAMEWORK_DIR = "C:/BMC/persist/automation_libs"
base_path = "C:/Program Files/BMC Software/RLM"
input_file = "#{base_path}/automation_results/request/ROMS/14289/step_157935/scriptinput_174_1430847109.txt"
@params = YAML.load(File.open(input_file).read)
require "#{FRAMEWORK_DIR}/brpm_framework"
nsh_cmd = "ls //clm-aus-003365.bmc.com/c/program\\ files/bmc\\ software/rlm/server/jboss/standalone/log/server.log"
