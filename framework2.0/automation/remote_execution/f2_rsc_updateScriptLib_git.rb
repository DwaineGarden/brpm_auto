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
@script_name_handle = "update_git"
result = eval(body)

#---------------------- Methods ------------------------------#
  
#---------------------- Main Script ------------------------------#
def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
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
    @rpm.log "Here is a message"
    status = `cd #{ACTION_LIBRARY_PATH} ; git pull origin master`
    log_it("Git result: #{status}")
    lines = status.split("\n")
    default_list("Git: #{lines[0]}")    
  rescue Exception => e
    log_it "#{e.message}\n#{e.backtrace}"
  end
end


