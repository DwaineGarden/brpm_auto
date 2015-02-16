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

#---------------------- Declarations ------------------------------#
FRAMEWORK_DIR = @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib") unless defined?(FRAMEWORK_DIR)
body = File.open(File.join(FRAMEWORK_DIR,"lib","resource_framework.rb")).read
result = eval(body)
@script_name_handle = "update_svn"
load_customer_include(FRAMEWORK_DIR)

#---------------------- Methods ------------------------------#
  
#---------------------- Main Script ------------------------------#
def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  svn_path = "/opt/svn/1.7.5/opt/CollabNet_Subversion/bin/svn"
  cmd_options = "--non-interactive  --trust-server-cert --force"
  prerun = "export LD_LIBRARY_PATH=#{svn_path.gsub("bin/svn", "lib")}"
  rpm_svn_url = "https://svn.nam.nsroot.net:9050"
  svn_username = "rlmadmin"
  svn_password_enc = "__SS__Ck54a1UwNFdhdFJXUQ=="
  pout = []
  script_params.each{|k,v| pout << "#{k} => #{v}" }
  log_it "Current Params:\n#{pout.sort.join("\n") }"
  unless script_params["Update Action Library"] == "yes"
    no_list = default_list("update set to no")
    log_it no_list 
    return no_list
  end
  raise "Command_Failed: no library path defined, set property: ACTION_LIBRARY_PATH" if !defined?(ACTION_LIBRARY_PATH)
  begin
    credential = "--username #{svn_username} --password #{decrypt_string_with_prefix(svn_password_enc)}"
    svn_cmd = "#{prerun} && #{svn_path} export #{credential} #{cmd_options} ."
    status = `cd #{ACTION_LIBRARY_PATH} ; #{svn_cmd}`
    log_it("Svn result: #{status}")
    lines = status.split("\n")
    default_list("Svn: #{lines[0]}")    
  rescue Exception => e
    log_it "#{e.message}\n#{e.backtrace}"
  end
end


