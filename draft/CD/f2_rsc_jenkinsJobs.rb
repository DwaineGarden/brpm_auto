# Description: Resource to choose the tech stack(components) for deployment
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 

#=== General Integration Server: RLMJenkins ===#
# [integration_id=10020]
SS_integration_dns = "http://vw-aus-rem-dv11.bmc.com:8080"
SS_integration_username = "bbyrd"
SS_integration_password = "-private-"
SS_integration_details = ""
SS_integration_password_enc = "__SS__Cj1Jek1QTjBaTkYyUQ=="
#=== End ===#

#---------------------- Declarations ------------------------------#
@script_name_handle = "choose_jenkins"
FRAMEWORK_DIR = "/opt/bmc/persist/automation_lib"
eval File.open("#{FRAMEWORK_DIR}/brpm_framework.rb").read

#---------------------- Methods --------------------------------#

#---------------------- Main Body --------------------------#
  
def execute(script_params, parent_id, offset, max_records)
  #returns all the environments of a component
  require "#{FRAMEWORK_DIR}/lib/brpm_automation.rb"
  @rpm = BrpmAutomation.new(script_params)
  require "#{FRAMEWORK_DIR}/lib/jenkins.rb"
  log_it "Starting Automation"
  begin
    get_request_params
    @jenkins = Jenkins.new(SS_integration_dns, script_params, {"username" => SS_integration_username, "password" => decrypt_string_with_prefix(SS_integration_password_enc), "job_name" => "none"})
    temps = {}
    rest_result = @jenkins.job_list
    return default_list("NoProjectsReturned") unless rest_result.has_key?("jobs")
    rest_result["jobs"].each do |job|
      url = job["url"]
      job_uri = url[(url.index("job/") + 4)..(url.length - 1)]
      temps[job_uri] = job["name"]
    end
    @request_params["jenkins_jobs"] = rest_result["jobs"]
    log_it temps
    
    result = hashify_list(temps)
    select_hash = {}
    select_hash["Select"] = ""
    result.unshift(select_hash)
    write_to result.inspect
    save_request_params
    log_it(result)
  rescue Exception => e
    log_it "Error: #{e.message}\n#{e.backtrace}"
  end
  return result
end

def import_script_parameters
  { "render_as" => "List" }
end
