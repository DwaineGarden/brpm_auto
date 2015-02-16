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

  def default_list(msg)
    result = [{msg => 0}]
    select_hash = {}
    result.unshift(select_hash)
  end  

  def log_it(it)
    log_path = File.join(@params["SS_automation_results_dir"], "resource_logs")
    txt = it.is_a?(String) ? it : it.inspect
    write_to txt
    Dir.mkdir(log_path) unless File.exist?(log_path)
    s_handle = defined?(@script_name_handle) ? @script_name_handle : "rsc_output"
    fil = File.open("#{log_path}/#{s_handle}_#{@params["SS_run_key"]}", "a")
    fil.puts txt
    fil.flush
    fil.close
  end
  
  def load_customer_include(framework_dir)
    customer_include_file = File.join(framework_dir, "customer_include.rb")
    begin
      if File.exist?(customer_include_file)
        log_it "Loading customer include file: #{customer_include_file}"
        eval(File.open(customer_include_file).read) 
      elsif File.exist customer_include_file = File.join(framework_dir,"customer_include_default.rb")
        log_it "Loading default customer include file: #{customer_include_file}"
        eval(File.open(customer_include_file).read)
      end
    rescue Exception => e
      log_it "Error loading customer include: #{e.message}\n#{e.backtrace}"
    end 
  end
    
  def hashify_list(list)
    response = {}
    list.each do |item,val| 
      response[val] = item
    end
    return [response]
  end
  
  def action_library_path
    raise "Command_Failed: no library path defined, set property: ACTION_LIBRARY_PATH" if !defined?(ACTION_LIBRARY_PATH)
    ACTION_LIBRARY_PATH
  end
end

extend ResourceFramework

