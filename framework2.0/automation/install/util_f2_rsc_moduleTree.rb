#  util_f2_rsc_moduleTree
#  Resource automation to present a tree control for file browsing via nsh
#  Called by util_f2_installModule

#---------------------- Declarations ------------------------------#
FRAMEWORK_DIR = @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib") unless defined?(FRAMEWORK_DIR)
@script_name_handle = "library_tree"
body = File.open(File.join(FRAMEWORK_DIR,"lib","resource_framework.rb")).read
result = eval(body)

#---------------------- Methods ------------------------------#

#---------------------- Main Script ------------------------------#
def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  library_root = File.join(FRAMEWORK_DIR,"..","automation")
  log_it "ModuleLibrary: #{library_root}"
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

