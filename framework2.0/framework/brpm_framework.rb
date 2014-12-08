# = BRPM Automation Framework
#    BMC Software - BJB 8/22/2014, BJB 9/17/14
# ==== A collection of classes to simplify building BRPM automation
# === Instructions
# In your BRPM automation include a block like this to pull in the library
# <tt> params["direct_execute"] = true #Set for local execution
# <tt> require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")

SleepDelay = [5,10,25,60] # Pattern for sleep pause in polling 
RLM_BASE_PROPERTIES = ["SS_application", "SS_environment", "SS_component", "SS_component_version", "request_id", "step_name"]

# Compatibility Routines
def get_request_params
   none = "" # just so it doesn't  fail
end

def save_request_params
  @p.save_local_params
end

def rpm_load_module(*module_names)
  result = ""
  module_names.each do |mod_name|
    load_path = "#{FRAMEWORK_DIR}/lib/#{mod_name}"
    if File.exist?("#{load_path}.rb")
      require load_path
      result += "success - #{load_path}\n"
    else
      result += "ERROR - file not found #{load_path}\n"
    end
  end
  result
end

# == Initialization on Include
# Objects are set for most of the classes on requiring the file
# these will be available in the BRPM automation
#  Customers should modify the BAA_BASE_PATH constant
# == Note the customer_include.rb reference.  To add your own routines and override methods use this file.
if @params["SS_script_target"] == "resource_automation"
  # do something else
else
  @request_params = {} if not defined?(@request_params)
  SS_output_file = @params["SS_output_file"]
  FRAMEWORK_DIR = @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib") unless defined?(FRAMEWORK_DIR)
  rpm_load_module("param", "rest") # baa_transport, nsh_transport, ssh_transport, legacy_framework, scm, ticket, dispatch_baa, dispath_nsh
  @p = Param.new(@params, @request_params)
  customer_include_file = File.join(FRAMEWORK_DIR, "customer_include.rb")
  if File.exist?(customer_include_file)
    @rpm.log "Loading customer include file: #{customer_include_file}"
    require customer_include_file
  elsif File.exist customer_include_file = File.join(FRAMEWORK_DIR,"customer_include_default.rb")
    @rpm.log "Loading default customer include file: #{customer_include_file}"
    require customer_include_file
  end
  @request_params = @p.get_local_params
  ARG_PREFIX = "ARG_" unless defined?(ARG_PREFIX)
  @rest = BrpmRest.new(@p.SS_base_url, @params)
  #Load the transport for the step, transport follows environment property SS_transport
  transport = @p.get("SS_transport", @p.get("ss_transport", "nsh"))
  @p.assign_local_param("ss_transport", transport)
  @p.find_or_add("SS_transport", transport)
  @p.save_local_params
  @rpm.log "Loading transport modules for: #{transport}"
  rpm_load_module("transport_#{transport}", "dispatch_#{transport}")
end

