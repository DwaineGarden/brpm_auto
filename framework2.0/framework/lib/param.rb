# Abstraction class for the step params
# provides convenience routines for working with params
class Param < BrpmAutomation

  # Initialize an instance of the class
  #
  # ==== Attributes
  #
  # * +params+ - send the step params
  # * +json_params+ - the local file-based params for the request (will create if it doesn't exist)
  def initialize(params, json_params = {})
    @params = params
    @json_params = json_params
    @output_file = @params["SS_output_file"]
    request_data_file_dir = File.dirname(@params["SS_output_dir"])
    @request_data_file = "#{request_data_file_dir}/request_data.json"
    @server_list = server_list
  end
  
  # Test if a param is present
  #
  # ==== Attributes
  #
  # * +key_name+ - key to look for
  # * +where+ - if true returns the hash where the key was found
  #
  # ==== Returns
  #
  # * the param hash name if where=true, otherwise true/false
  def present?(key_name, where = false)
    ans = nil
    ans = "params" if present_local?(key_name) 
    ans = "json" if present_json?(key_name)
    where ? ans : !ans.nil?
  end

  def present_json?(key_name)
    @json_params.has_key?(key_name)
  end
   
  def present_local?(key_name)
    @params.has_key?(key_name)
  end
 
  # Adds a key/value to the params
  #
  # ==== Attributes
  #
  # * +key_name+ - key name
  # * +value+ - value to assign
  #
  # ==== Returns
  #
  # * value added
  def add(key_name, value)
    @params[key_name] = value
  end
  
  # Adds a key/value to the params if not found
  #
  # ==== Attributes
  #
  # * +key_name+ - key name
  # * +value+ - value to assign
  #
  # ==== Returns
  #
  # * value of key
  def find_or_add(key_name, value)
    ans = get(key_name)
    add(key_name, value) if ans == ""
    ans == "" ? value : ans
  end
  
  # Finds a key in params or json_params
  #
  # ==== Attributes
  #
  # * +key_name+ - key name
  # * +default+ - value to return if key is blank or not found
  #
  # ==== Returns
  #
  # * value of key - including resolved properties that may be embedded
  # *  Like this: /opt/bmc/${component_version}/appserver
  def get(key_name, default = "")
    ans = nil
    ans = @json_params[key_name] if present_json?(key_name)
    ans = @params[key_name] if present_local?(key_name)
    ans = default if ans.nil? || ans == ""
    complex_property_value(ans)
  end  
  # Allows you to specify a key like a method call
  #
  # ==== Attributes
  #
  # * +key_name+ - key name note: you must use get if keyname has spaces
  # * +*args+ - allows you to send a default value
  #
  # ==== Returns
  #
  # * value of key - including resolved properties that may be embedded
  #
  # ==== Examples
  #
  #   @p = Params.new(params)
  #   @p.SS_application
  #   => "Sales"
  def method_missing(key_name, *args)
    ans = get(key_name.to_s)
    ans = args[0] if ans == "" && args[0]
    ans
  end
  
  # Raises an error if a key is not found
  #
  # ==== Attributes
  #
  # * +key_name+ - key name
  #
  # ==== Returns
  #
  # * value of key
  def required(key_name)
    raise "ParamsError: param #{key_name} must be present" unless present?(key_name) 
    get(key_name) 
  end
  
  # Creates the JSON params file if not present
  #
  # ==== Returns
  #
  # * path to file created
  def create_local_params
    fil = File.open(@request_data_file,"w")
    fil.puts "{\"request_data_file\":\"Created #{Time.now.strftime("%m/%d/%Y %H:%M:%S")}\"}"
    fil.flush; fil.close
    file_part = @request_data_file[@request_data_file.index("/automation_results")..255]
    data_file_url = "#{@params["SS_base_url"]}#{file_part}"
    log "Created new request data: #{data_file_url}"
    @request_data_file
  end

  def init_local_params
    sleep(2) unless File.exist?(@request_data_file)
    unless File.exist?(@request_data_file)
      create_local_params
    end
    file_part = @request_data_file[@request_data_file.index("/automation_results")..255]
    data_file_url = "#{@params["SS_base_url"]}#{file_part}"
    log "Request Run Data: #{data_file_url}"
    @request_data_file
  end

  # Fetches the contents of the json_params file
  #
  # ==== Returns
  #
  # * hash of the params 
  def get_local_params
    # Uses a json document in automation_results to store free-form information
    cur = init_local_params
    @json_params = JSON.parse(File.open(cur).read)
    @json_params.each{ |k,v| log("#{k} => #{v.is_a?(String) ? v : v.inspect}") }
    log "##------ End of Local Params --------##"
    @orig_request_params = @json_params.dup
    @json_params
  end

  # Fetches the property value for a server
  #
  # ==== Returns
  #
  # * property value 
  def get_server_property(server, property)
    ans = ""
    ans = @server_list[server][property] if @server_list.has_key?(server) && @server_list[server].has_key?(property)
    ans
  end

  # Pulls the json params from a different request
  #
  # ==== Attributes
  #
  # * +other_request+ - id of other request
  #
  # ==== Returns
  #
  # * hash of the other requests params file
  def get_other_request_params(other_request)
    # Uses a json document in automation_results to store free-form information
    request_data_file_dir = File.dirname(@params["SS_output_dir"])
    request_data_file_dir.gsub!("/#{@params["SS_request_number"]}","/#{other_request}")
    request_data_file = "#{request_data_file_dir}/request_data.json"
    request_params = JSON.parse(File.open(cur).read)
  end

  # Adds a key/value to the json_params
  #
  # ==== Attributes
  #
  # * +key_name+ - key name
  # * +value+ - value to assign
  #
  # ==== Returns
  #
  # * value added
  def assign_local_param(key, value)
    @json_params[key] = value
  end

  # Removes a key/value from the json_params
  #
  # ==== Attributes
  #
  # * +key_name+ - key name
  #
  # ==== Returns
  #
  # * key removed
  def remove_local_param(key)
    @json_params.delete(key)
  end
  
  # Saves json_params to the file system
  #  note: you must call this to save any changes
  # ==== Attributes
  #
  # * +key_name+ - key name
  # * +value+ - value to assign
  #
  def save_local_params
    # Uses a json document in automation_results to store free-form information
    unless @orig_request_params == @json_params
      sleep(2) unless File.exist?(cur)
      fil = File.open(@request_data_file,"w+")
      fil.write @json_params.to_json
      fil.close
    end
  end

  # returns the current json_params
  #
  # ==== Returns
  #
  # * hash of params
  def local_params
    @json_params
  end

  # returns the current params
  #
  # ==== Returns
  #
  # * hash of params
  def params
    @params
  end

  # Inserts a value in the json_params of another request
  #  note: be careful this has to be coordinated
  # ==== Attributes
  #
  # * +request_id+ - number of request to modify
  # * +updates+ - hash of keys/values to add
  #
  def update_other_request_params(request_id, updates = {})
    request_data_file_dir = File.dirname(@params["SS_output_dir"])
    request_data_file_dir.gsub!("/#{@params["SS_request_number"]}","/#{request_id}")
    request_data_file = "#{request_data_file_dir}/request_data.json"
    request_params = JSON.parse(File.open(request_data_file).read)
    updates.each do |k,v|
      request_params[k] = v
    end
    fil = File.open(request_data_file,"w+")
    fil.write request_params.to_json
    fil.close
  end

  # Resolves embedded properties in a string
  #  
  # ==== Attributes
  #
  # * +full_val+ - string to convert
  def complex_property_value(full_val)
    return full_val unless full_val.is_a?(String)
    reg = /\$\{.*?\}/
    found = full_val.scan(reg)
    return full_val if found.empty?
    result = full_val.dup
    found.each do |item|
      prop_name = item.gsub("\${","").gsub("}","")
      value = get(prop_name)
      result.gsub!("\${#{prop_name}}",value) unless value == ""
    end
    result
  end
  
  # Returns a server hash with properties from the params
  # 
  # ==== Returns
  #
  # hash of servers and properties
  # ex: {server1 => {prop => val1, Prop2 => val2}, server2 => {prop1 => val1}}
  #
  def server_list
    rxp = /server\d+_/
    slist = {}
    return slist unless @params.has_key?("servers")
    lastcur = -1
    curname = ""
    @params.sort.select{ |k| k[0] =~ rxp }.each_with_index do |server, idx|
      cur = (server[0].scan(rxp)[0].gsub("server","").to_i * 0.001).round * 1000
      if cur == lastcur
        prop = server[0].gsub(rxp, "")
        slist[curname][prop] = server[1]
      else # new server
        lastcur = cur
        curname = server[1].chomp("0")
        slist[curname] = {}
      end
    end 
    if slist.size == 0
      base_servers = @params["servers"].split(",")
      base_servers.each{|k| slist[k] = {} }
    end
    slist
  end
  
end
