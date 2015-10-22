
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
  
  # Makes an http method call and returns data in JSON
  #
  # ==== Attributes
  #
  # * +url+ - the url for the request
  # * +method+ - the http method [get, put, post]
  # * +options+ - a hash of options
  #      +verbose+: gives verbose output (yes/no)
  #      +data+: required for put and post methods a hash of post data
  #      +username+: username for basic http authentication
  #      +password+: password for basic http authentication
  #      +suppress_errors+: continues after errors if true
  #      
  # ==== Returns
  #
  # * returns a hash of the http response with these keys
  # * +status+ - success or ERROR
  # * +message+ - if status is ERROR this will hold an error message
  # * +code+ - the http status code 200=ok, 404=not found, 500=error, 504=not authorized
  # * +data+ - the body of the http response
  def rest_call(url, method, options = {})
    methods = %w{get post put}
    result = {"status" => "ERROR", "response" => "", "message" => ""}
    method = method.downcase
    verbose = get_option(options, "verbose") == "yes" || get_option(options, "verbose")
    headers = get_option(options, "headers", {:accept => :json, :content_type => :json})
    return result["message"] = "ERROR - #{method} not recognized" unless methods.include?(method)
    log_it "Rest URL: #{url}" if verbose
    begin
      data = get_option(options, "data")
      rest_params = {}
      rest_params[:url] = url
      rest_params[:method] = method.to_sym
      rest_params[:verify_ssl] = OpenSSL::SSL::VERIFY_NONE if url.start_with?("https")
      rest_params[:payload] = data.to_json unless data == ""
      if options.has_key?("username") && options.has_key?("password")
        rest_params[:user] = options["username"]
        rest_params[:password] = options["password"]
      end
      rest_params[:headers] = headers
      log_it "RestParams: #{rest_params.inspect}" if verbose
      if %{put post}.include?(method)
        return result["message"] = "ERROR - no data param for post" if data == ""
        response = RestClient::Request.new(rest_params).execute
      else
        response = RestClient::Request.new(rest_params).execute
      end
    rescue Exception => e
      result["message"] = e.message
      raise "RestError: #{result["message"]}" unless get_option(options, "suppress_errors") == true
      return result
    end
    log_it "Rest Response:\n#{response.inspect}" if verbose
    if headers[:accept] == :json
      parsed_response = JSON.parse(response) rescue nil
    else
      parsed_response = response
    end
    parsed_response = {"info" => "no data returned"} if parsed_response.nil?
    result["code"] = response.code
    if response.code < 300
      result["status"] = "success"
      result["data"] = parsed_response
    elsif response.code == 422
      result["message"] = "REST call returned code 422 usually a bad token"
    else
      result["message"] = "REST call returned HTTP code #{response.code}"
    end
    if result["status"] == "ERROR"
      raise "RestError: #{result["message"]}" unless get_option(options, "suppress_errors") == true
    end
    result
  end
  
  # Provides a simple failsafe for working with hash options
  # returns "" if the option doesn't exist or is blank
  # ==== Attributes
  #
  # * +options+ - the hash
  # * +key+ - key to find in options
  # * +default_value+ - if entered will be returned if the option doesn't exist or is blank
  def get_option(options, key, default_value = "")
    result = options.has_key?(key) ? options[key] : nil
    result = default_value if result.nil? || result == ""
    result 
  end
  
end

extend ResourceFramework

