#--------------------- DECLARATIONS ------------------------------#
# This dispatcher will be invoked to execute a remote shell automation via nsh.
# The server list passed to this script will all execute the same action file
# generated from the remote shell automation and command generated from the #! line.

@DEFAULT_CHANNEL_ROOT = '/tmp'
@WINDOWS_CHANNEL_ROOT = '/C/windows/temp'
@NUM_THREADS = 10 # degree of parallelism for this dispatcher
@NSH_OPTIONS = {
    nsh_path: '', # set to NSH dir path if nsh commands are not in PATH
    nshrunner: false, # set to true if you want to use nshrunner
    verbose: true,
    test_mode: false
}

@nsh_run = NshDispatchScript.new(params, @NSH_OPTIONS)

@pack_response_helper = PackResponseHelper.new
@nsh_run.pack_response_helper = @pack_response_helper

#---------- FRAMEWORK ADDITIONS ------------------#
# = BRPM Automation Framework - Dispatcher Edition
# = (c) BMC Software - BJB 12-3-15

require 'popen4'
require 'timeout'
require 'erb'
@framework_dir = defined?(FRAMEWORK_DIR) ? FRAMEWORK_DIR : File.dirname(File.dirname(__FILE__))

def enhance_params(params)
  @p.local_params.each{|k,v| params[k] = v if v.is_a?(String) || v.is_a?(Fixnum) }
  params
end

def process_script(script_path)
  conts = File.read(script_path)
  action_txt = ERB.new(conts).result(binding)
  File.open(script_path, "w+") do |fil|
    fil.puts action_txt
    fil.flush
  end
end
  
# == Initialization on Include
# Objects are set for most of the classes on requiring the file
# these will be available in the BRPM automation
#  Customers should modify the BAA_BASE_PATH constant
# == Note the customer_include.rb reference.  To add your own routines and override methods use this file.
customer_include_file = File.join(@framework_dir, "customer_include.rb")
customer_include_file = File.join(CUSTOMER_LIB_DIR,"customer_include.rb") if defined?(CUSTOMER_LIB_DIR)
customer_include_file = File.join(File.dirname(@framework_dir.gsub("/BRPM/framework", "")), "customer_include.rb")
customer_include_file = File.join(@framework_dir,"customer_include_default.rb") if !File.exist?(customer_include_file)
conts = File.open(customer_include_file).read
eval conts # Use eval for resource automation to be dynamic

require "#{@framework_dir}/lib/brpm_automation"
@rpm = BrpmAutomation.new(@params)
@rpm.log "Loading customer include file: #{customer_include_file}"

@request_params = {} if not defined?(@request_params)
SS_output_file = @params["SS_output_file"]
require "#{@framework_dir}/lib/param"
@p = Param.new(@params, @request_params)
@request_params = @p.get_local_params
ARG_PREFIX = "ARG_" unless defined?(ARG_PREFIX)

@rpm.message_box "Executing Remote Shell Script"
@rpm.log "Script: #{@p.SS_action_name}"
@rpm.log "Hosts: #{get_selected_hosts.inspect}\n"

enhance_params(params)

#---------------------FRAMEWORK ADDITIONS (end) ------------------#

#--------------------- METHODS ------------------------------------#
def change_wrapper_permission(servers = [])
  servers.each do |server|
    @nsh_run.nsh_command("chmod u+x \"//#{server}#{@wrapper_remote_path}\"")
  end
end

def remove_wrapper(servers = [])
  servers.each do |server|
    @nsh_run.nsh_command("rm -f \"//#{server}#{@wrapper_remote_path}\"")
  end
end

def remove_action(servers = [])
  servers.each do |server|
    @nsh_run.nsh_command("rm -f \"//#{server}#{@target_path}/#{@params["SS_action_name"]}\"")
  end
end

def push_and_run(srun_wrapper, servers, props, num_threads = 1)
  @target_path = get_target_path(@params.merge(props))
  servers = [servers] unless servers.is_a?(Array)
  @nsh_run.log_tag_list = servers
  @nsh_run.set_nsh_blcred(props)
  begin
    @nsh_run.ncp(servers, @params['SS_action_file'], @target_path, num_threads)
    @nsh_run.ncp(servers, srun_wrapper, @target_path, num_threads)
    @wrapper_remote_path = "#{@target_path}/#{srun_wrapper.split('/').last}"
    change_wrapper_permission(servers)
    @nsh_run.script_exec([servers], @wrapper_remote_path, @target_path, { num_threads: num_threads })
  ensure
    remove_wrapper(servers)
    remove_action(servers)
  end
end

#--------------------- MAIN --------------------------------------#
process_script(@params['SS_action_file'])

if @nsh_run.bulk_copy?
  win_server_list = []
  unix_server_list = []

  unix_servers.each do |server, props|
    unix_server_list << server_addr(server, props)
  end

  win_servers.each do |server, props|
    win_server_list << server_addr(server, props)
  end

  if unix_servers.any?
    unix_props = unix_servers.first[1]
    srun_wrapper = @nsh_run.unix_srun_wrapper(params.merge(unix_props))
    push_and_run(srun_wrapper, unix_server_list, unix_props, @NUM_THREADS.to_i > 0 ? @NUM_THREADS.to_i : 1)
  end

  if win_servers.any?
    win_props = win_servers.first[1]
    srun_wrapper = @nsh_run.windows_srun_wrapper(params.merge(win_props))
    push_and_run(srun_wrapper, win_server_list, win_props, @NUM_THREADS.to_i > 0 ? @NUM_THREADS.to_i : 1)
  end
else
  win_servers.each do |server, props|
    srun_wrapper = @nsh_run.windows_srun_wrapper(params.merge(props))
    push_and_run(srun_wrapper, server_addr(server, props), props)
  end

  unix_servers.each do |server, props|
    srun_wrapper = @nsh_run.unix_srun_wrapper(params.merge(props))
    push_and_run(srun_wrapper, server_addr(server, props), props)
  end
end

puts_stdout @pack_response_helper.pack_responses
