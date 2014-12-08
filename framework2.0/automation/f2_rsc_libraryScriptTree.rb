#  f2_rsc_LibraryScriptTree
#  Resource automation to present a tree control for file browsing via nsh
#  Called by f2_nsh_filePicker

#---------------------- Declarations ------------------------------#
FRAMEWORK_DIR = @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib") unless defined?(FRAMEWORK_DIR)


#---------------------- Methods ------------------------------#
module ResourceFramework
  def create_request_params_file
    request_data_file_dir = File.dirname(@params["SS_output_dir"])
    request_data_file = "#{request_data_file_dir}/request_data.json"
    fil = File.open(request_data_file,"w")
    fil.puts "{\"request_data_file\":\"Created #{Time.now.strftime("%m/%d/%Y %H:%M:%S")}\"}"
    fil.close
    file_part = request_data_file[request_data_file.index("/automation_results")..255]
    data_file_url = "#{@params["SS_base_url"]}#{file_part}"
    write_to "Request Run Data: #{data_file_url}"
    request_data_file
  end

  def init_request_params
    request_data_file_dir = File.dirname(@params["SS_output_dir"])
    request_data_file = "#{request_data_file_dir}/request_data.json"
    sleep(2) unless File.exist?(request_data_file)
    unless File.exist?(request_data_file)
      create_request_params_file  
    end
    file_part = request_data_file[request_data_file.index("/automation_results")..255]
    data_file_url = "#{@params["SS_base_url"]}#{file_part}"
    write_to "Request Run Data: #{data_file_url}"
    request_data_file
  end

  def get_request_params
    # Uses a json document in automation_results to store free-form information
    cur = init_request_params
    #message_box("Current Request Data","sep")
    @request_params = JSON.parse(File.open(cur).read)
    @request_params.each{ |k,v| write_to("#{k} => #{v.is_a?(String) ? v : v.inspect}") }
    @orig_request_params = @request_params.dup
    @request_params
  end

  def save_request_params
    # Uses a json document in automation_results to store free-form information
    cur = init_request_params
    unless @orig_request_params == @request_params
      sleep(2) unless File.exist?(cur)
      fil = File.open(cur,"w+")
      fil.write @request_params.to_json
      fil.flush
      fil.close
    end
  end

  def default_table(other_rows = nil)
    totalItems = 1
    table_entries = [["#","Status","Information"]]
    table_entries << ["1","Error", "Insufficient Data"] if other_rows.nil?
    other_rows.each{|row| table_entries << row } unless other_rows.nil?
    per_page=10
    {:totalItems => totalItems, :perPage => per_page, :data => table_entries }
  end  

  def log_it(it)
    log_path = File.join(@params["SS_automation_results_dir"], "resource_logs")
    txt = it.is_a?(String) ? it : it.inspect
    write_to txt
    Dir.mkdir(log_path) unless File.exist?(log_path)
    fil = File.open("#{log_path}/output_filetree_#{@params["SS_run_key"]}", "a")
    fil.puts txt
    fil.close
  end
  
  def load_customer_include
    customer_include_file = File.join(FRAMEWORK_DIR, "customer_include.rb")
    if File.exist?(customer_include_file)
      @rpm.log "Loading customer include file: #{customer_include_file}"
      require customer_include_file
    elsif File.exist customer_include_file = File.join(FRAMEWORK_DIR,"customer_include_default.rb")
      @rpm.log "Loading default customer include file: #{customer_include_file}"
      require customer_include_file
    end
  end
    
  def hashify_list(list)
    response = {}
    list.each do |item,val| 
      response[val] = item
    end
    return [response]
  end
  
end

#require File.join(FRAMEWORK_DIR,"lib","resource_framework")
extend ResourceFramework
load_customer_include

#---------------------- Main Script ------------------------------#
def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  pout = []
  script_params.each{|k,v| pout << "#{k} => #{v}" }
  log_it "Current Params:\n#{pout.sort.join("\n") }"
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

