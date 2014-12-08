#  f2_rsc_LibraryScriptTree
#  Resource automation to present a tree control for file browsing via nsh
#  Called by f2_nsh_filePicker

#---------------------- Declarations ------------------------------#
FRAMEWORK_DIR = @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib") unless defined?(FRAMEWORK_DIR)

#---------------------- Methods ------------------------------#
require File.join(FRAMEWORK_DIR,"lib","resource_framework")
extend ResourceFramework
load_customer_include

#---------------------- Main Script ------------------------------#
def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  #pout = []
  #script_params.each{|k,v| pout << "#{k} => #{v}" }
  #log_it "Current Params:\n#{pout.sort.join("\n") }"
  raise "Command_Failed: no library path defined, set property: SCRIPT_LIBRARY_ROOT" if !defined?(SCRIPT_LIBRARY_ROOT)
  library_root = SCRIPT_LIBRARY_ROOT
  begin
    if parent_id.blank?
      # root folder
      log_it "Setting root: /"
      data = []
      Dir.entries(library_root).reject{|l| l.start_with?(".") }.sort.each do |file|
        data << { :title => file, :key => "#{file}|/", :isFolder => true, :hasChild => true}
      end
      return data
    else
      # clicked_item|/opt/bmc/stuff
      log_it "Drilling in: #{parent_id}"
      dir = File.join(library_root, parent_id.split("|")[1],parent_id.split("|")[0])
      dir = "/#{dir}" if parent_id.split("|")[1] == "//"
      entries = Dir.entries(dir).reject{|l| l.start_with?(".") }.sort
      return [] if entries.nil?
      data = []
      entries.each do |path|
        is_folder = File.directory?(File.join(dir,path))
        data << { :title => path, :key => "#{path}|#{dir}", :isFolder => is_folder, :hasChild => is_folder}
      end
      log_it(data)
      data
    end
  rescue Exception => e
    log_it "#{e.message}\n#{e.backtrace}"
  end
end

def import_script_parameters
  { "render_as" => "Tree" }
end

