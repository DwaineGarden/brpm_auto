#  f2_rsc_LibraryScriptTree
#  Resource automation to present a tree control for file browsing via local

#---------------------- Declarations ------------------------------#
@script_name_handle = "library_tree"
conts = File.open('C:/BMC/persist/automation_libs/brpm_framework.rb').read
eval conts

#---------------------- Methods ------------------------------#

#---------------------- Main Script ------------------------------#
def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  #pout = []
  #script_params.each{|k,v| pout << "#{k} => #{v}" }
  #log_it "Current Params:\n#{pout.sort.join("\n") }"
  library_root = action_library_path
  log_it "ActionLibrary: #{library_root}"
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
