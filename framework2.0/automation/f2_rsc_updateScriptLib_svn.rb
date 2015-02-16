#  f2_rsc_LibraryScriptTree
#  Resource automation to present a tree control for file browsing via nsh
#  Called by f2_executeLibraryAction
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
###
# Update Action Library:
#   name: yes/no update the script library
#   type: in-text
#   position: A2:B2
###

#=== General Integration Server: svn_github ===#
# [integration_id=9]
SS_integration_dns = "https://github.com"
SS_integration_username = "bradybyrd"
SS_integration_password = "-private-"
SS_integration_details = "svn_path: /usr/bin/svn
options: --no-auth-cache --non-interactive  --trust-server-cert --force"
SS_integration_password_enc = "__SS__Cj1NemJvRjJhalZIVg=="
#=== End ===#

#---------------------- Declarations ------------------------------#
FRAMEWORK_DIR = @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib") unless defined?(FRAMEWORK_DIR)
@script_name_handle = "update_svn"
body = File.open(File.join(FRAMEWORK_DIR,"lib","resource_framework.rb")).read
result = eval(body)

#---------------------- Methods ------------------------------#

#---------------------- Main Script ------------------------------#
def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  svn_path = get_integration_details("svn_path")
  svn_options = get_integration_details("options")
  svn_url = "#{SS_integration_dns}/BMC-RLM/brpm_auto/trunk/framework2.0/script_library"
  svn_base_dir = action_library_path
  prerun = "" #"export LD_LIBRARY_PATH=#{svn_path.gsub("bin/svn", "lib")} && "
  pout = []
  script_params.each{|k,v| pout << "#{k} => #{v}" }
  log_it "Current Params:\n#{pout.sort.join("\n") }"
  unless script_params["Update Action Library"] == "yes"
    no_list = default_list("update set to no")
    log_it no_list 
    return no_list
  end
  begin
    credential = "--username #{SS_integration_username} --password #{decrypt_string_with_prefix(SS_integration_password_enc)}"
    svn_cmd = "#{prerun}#{svn_path} export #{credential} #{svn_options} #{svn_url} ."
    log_it "Running: #{svn_cmd} in #{svn_base_dir}"
    FileUtils.cd(svn_base_dir, :verbose => true)
    status = `#{svn_cmd}`
    log_it("Svn result: #{status}")
    lines = status.split("\n")
    default_list("Svn: #{lines[-1]}")    
  rescue Exception => e
    log_it "#{e.message}\n#{e.backtrace}"
  end
end


