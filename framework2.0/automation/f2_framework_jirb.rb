require 'fileutils'
script_support = "/opt/bmc/rlm4/releases/current/RPM/lib/script_support"
persist = "/opt/bmc/rlm4/persist/automation_lib"
FileUtils.cd script_support, :verbose => true
require "#{persist}/lib/ssh_script_header"

input_file = "/opt/bmc/rlm/automation_results/request/Utility/21675/step_34584/scriptinput_11260_1416331563.txt"

script_params = params = load_input_file(input_file)

require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")