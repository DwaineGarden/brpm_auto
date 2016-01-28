require 'yaml'
require 'json'
#FRAMEWORK_DIR = "C:/BMC/persist/automation_libs"
FRAMEWORK_DIR = "/opt/bmc/resources/persist/automation_lib"
base_path = "/opt/bmc/resources"
input_file = "#{base_path}/automation_results/request/JFP_GBIPB_BW/1367/step_4941/scriptinput_208_1421610040.txt"
@params = YAML.load(File.open(input_file).read)
require "#{FRAMEWORK_DIR}/brpm_framework"

#=== BMC Application Automation Integration Srerver: EC2 BSA Appserver ===#
# [integration_id=5]
SS_integration_dns = "https://ip-172-31-36-115.ec2.internal:9843/"
SS_integration_username = "BLAdmin"
SS_integration_password = "-private-"
SS_integration_details = "role: BLAdmins
authentication_mode: SRP"
SS_integration_password_enc = "__SS__Cj09d1lwZDJic1ZHWmh4bVk="
#=== End ===#
require "#{@p.SS_script_support_path}/baa_utilities"
require "#{FRAMEWORK_DIR}/lib/transport_baa"
@baa = TransportBAA.new(SS_integration_dns, @params)
@baa.set_credential(SS_integration_dns, SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc), "BLAdmins")
