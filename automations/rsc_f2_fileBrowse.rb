#  nsh_rsc_fileBrowse
#  Resource automation to present a tree control for file browsing via nsh
#  Called by f2_nsh_filePicker

#---------------------- Declarations ------------------------------#


#---------------------- Methods ------------------------------#

def log_it(it)
  #log_path = "/Users/brady/Documents/dev_rpm/logs"
  log_path = "/home/bbyrd/logs"
  txt = it.is_a?(String) ? it : it.inspect
  write_to txt
  return unless File.exist?(log_path)
  fil = File.open("#{log_path}/output_dir_#{@params["SS_run_key"]}", "a")
  fil.puts txt
  fil.close
end

#---------------------- Main Script ------------------------------#
def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  pout = []
  script_params.each{|k,v| pout << "#{k} => #{v}" }
  log_it "Current Params:\n#{pout.sort.join("\n") }"
  
  begin
    if parent_id.blank?
      # root folder
      log_it "Setting root: /"
      data = []
      Dir.entries("/").reject{|l| l.start_with?(".") }.sort.each do |file|
        data << { :title => file, :key => "#{file}|/", :isFolder => true, :hasChild => true}
      end
      return data
    else
      # clicked_item|/opt/bmc/stuff
      log_it "Drilling in: #{parent_id}"
      dir = File.join(parent_id.split("|")[1],parent_id.split("|")[0])
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