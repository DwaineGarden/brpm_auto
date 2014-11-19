# = BRPM Automation Framework
#    BMC Software - BJB 8/22/2014, BJB 9/17/14
# ==== A collection of classes to simplify building BRPM automation
# === Instructions
# In your BRPM automation include a block like this to pull in the library
# <tt> params["direct_execute"] = true #Set for local execution
# <tt> require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")

require 'json'
require 'rest-client'
require 'net/http'
require 'savon'
require 'yaml'
require 'uri'
require 'popen4'

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
  module_names.each do |mod_name|
    require "#{LibDir}/lib/#{mod_name}"
  end
end

# == Initialization on Include
# Objects are set for most of the classes on requiring the file
# these will be available in the BRPM automation
#  Customers should modify the BAA_BASE_PATH constant
# == Note the customer_include.rb reference.  To add your own routines and override methods use this file.
@request_params = {} if not defined?(@request_params)
SS_output_file = @params["SS_output_file"]
LibDir = File.expand_path(File.dirname(__FILE__))
require "#{LibDir}/lib/param"
@p = Param.new(@params, @request_params)
require "#{LibDir}/lib/legacy_framework"
#require "#{LibDir}/lib/baa"
#require "#{LibDir}/lib/scm"
#require "#{LibDir}/lib/nsh"
#require "#{LibDir}/lib/dispatch_srun"
require "#{LibDir}/lib/rest"
#require "#{LibDir}/lib/ticket"
#require "#{LibDir}/lib/action"
customer_include_file = File.join(LibDir,"customer_include.rb")
if File.exist?(customer_include_file)
  @rpm.log "Loading customer include file: #{customer_include_file}"
  require customer_include_file
end
ARG_PREFIX = "ARG_" unless defined?(ARG_PREFIX)
@rest = BrpmRest.new(@p.SS_base_url, @params)
@request_params = @p.get_local_params
@params["direct_execute"] = true #Set to exclude capistrano
global_timestamp


