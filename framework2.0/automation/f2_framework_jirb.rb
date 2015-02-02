require 'fileutils'
rlm_base_path = "/opt/bmc/RLM4.4"
#rlm_base_path = "/opt/bmc/rlm4"
script_support = "#{rlm_base_path}/releases/RPM/current/lib/script_support"
persist = "#{rlm_base_path}/persist/automation_lib"
FileUtils.cd script_support, :verbose => true
require "#{script_support}/ssh_script_header"

input_file = "#{rlm_base_path}/automation_results/request/Utility/21675/step_34584/scriptinput_11260_1416331563.txt"
input_file = "/opt/bmc/RLM4.4/automation_results/request/JFP_GBIPB_BW/1367/step_4941/scriptinput_208_1421610040.txt"

script_params = params = load_input_params(input_file)

require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")