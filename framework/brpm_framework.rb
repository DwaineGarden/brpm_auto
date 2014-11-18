# = BRPM Automation Framework
#    BMC Software - BJB 8/22/2014, BJB 9/17/14
# ==== A collection of classes to simplify building BRPM automation
# === Instructions
# In your BRPM automation include a block like this to pull in the library
# <tt> params["direct_execute"] = true #Set for local execution
# <tt> require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")

require 'json'
require 'rest-client'
require 'net/http'
require 'savon'
require 'yaml'
require 'uri'
require 'popen4'

  SleepDelay = [5,10,25,60] # Pattern for sleep pause in polling 
  RLM_BASE_PROPERTIES = ["SS_application", "SS_environment", "SS_component", "SS_component_version", "request_id", "step_name"]
  #Token = "f0c5708c888ff5b26c165673b6b7541db950953e"
  
# The base class for automation
# Provides convenience routines for working in BRPM
class BrpmAutomation

  # Initialize an instance of the class
  #
  # ==== Attributes
  #
  # * +output_object+ - the output file for logging or a reference to a Param object
  def initialize(output_object = nil)
    @fil = nil
    @p_obj = nil
    if output_object.nil?
      @output_file = SS_output_file
    elsif output_object.is_a?(String)
      @output_file = output_object
    else
      @p_obj = output_object
      @output_file = @p_obj.SS_output_file
    end
  end
  
  # Provides a simple failsafe for working with hash options
  # returns "" if the option doesn't exist or is blank
  # ==== Attributes
  #
  # * +options+ - the hash
  # * +key+ - key to find in options
  # * +default_value+ - if entered will be returned if the option doesn't exist or is blank
  def get_option(options, key, default_value = "")
    result = options.has_key?(key) ? options[key] : default_value
    result = default_value if result.is_a?(String) && result == ""
    result 
  end

  # Throws an error if an option is missing
  #  great for checking if properties exist
  #
  # ==== Attributes
  #
  # * +options+ - the options hash
  # * +key+ - key to find
  def required_option(options, key)
    result = get_option(options, key)
    raise ArgumentError, "Missing required option: #{key}" if result == ""
    result
  end

  # Provides a logging style output
  #
  # ==== Attributes
  #
  # * +txt+ - the text to output
  # * +level+ - the log level [info, warn, ERROR]
  # * +output_file+ - an alternate output file to log to (default is step output)
  def log(txt, level = "INFO", output_file = nil)
    safe_txt = privatize(txt)
    @output_file = output_file unless output_file.nil?
    puts log_message(safe_txt, level)
    unless @output_file.nil?
      @fil = File.open(@output_file,"a") if @fil.nil?
      @fil.puts(log_message(safe_txt, level))
      @fil.flush
      #fil.close
    end
  end

  # Provides a pretty box for titles
  #
  # ==== Attributes
  #
  # * +msg+ - the text to output
  # * +mtype+ - box type to display sep: a separator line, title a box around the message
  def message_box(msg, mtype = "sep")
    tot = 72
    msg = msg[0..64] if msg.length > 65
    ilen = tot - msg.length
    if mtype == "sep"
      start = "##{"-" * (ilen/2).to_i} #{msg} "
      res = "#{start}#{"-" * (tot- start.length + 1)}#"
    else
      res = "##{"-" * tot}#\n"
      start = "##{" " * (ilen/2).to_i} #{msg} "
      res += "#{start}#{" " * (tot- start.length + 1)}#\n"
      res += "##{"-" * tot}#\n"   
    end
    log(res)
  end

  # Runs a command on the shell capturing STDOUT and STDERR
  # provides thread separation to prevent blocking
  # ==== Attributes
  #
  # * +cmd+ - the command to run
  # ==== Returns
  #
  # * a hash of the command output with keys ["stdout","stderr","pid"]
  def run_shell(cmd)
      cmd_result = {"stdout" => "","stderr" => "", "pid" => ""}
      begin
          status = IO.popen4(cmd) do |pid, stdin, stdout, stderr|
            stdin.close
            [
              Thread.new(stdout) {|stdout_io|
                stdout_io.each_line do |l|
                  cmd_result["stdout"] += l
                end
                stdout_io.close
              },
    
              Thread.new(stderr) {|stderr_io|
                stderr_io.each_line do |l|
                 cmd_result["stderr"] += l
                end
              }
            ].each( &:join )
            cmd_result["pid"] = pid
          end
      rescue Exception => e
        cmd_result["stderr"] += "#{e.message}\n#{e.backtrace}"
      end
      cmd_result
  end
    
  # Takes the command result from run command and build a pretty display
  #
  # ==== Attributes
  #
  # * +cmd_result+ - the command result hash
  # ==== Returns
  #
  # * a hash of the command output with keys ["stdout","stderr","pid"]
  def display_result(cmd_result)
    result = "Process: #{cmd_result["pid"]}\nSTDOUT:\n#{cmd_result["stdout"]}\n"
    result = "STDERR:\n #{cmd_result["stderr"]}\n#{result}" if cmd_result["stderr"].length > 2
    result
  end
  
  # Makes an http method call and returns data in JSON
  #
  # ==== Attributes
  #
  # * +url+ - the url for the request
  # * +method+ - the http method [get, put, post]
  # * +options+ - a hash of options
  #      +verbose+: gives verbose output
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
    verbose = get_option(options, "verbose") == "yes" or get_option(options, "verbose")
    return result["message"] = "ERROR - #{method} not recognized" unless methods.include?(method)
    log "Rest URL: #{url}" if verbose
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
      rest_params[:headers] = {:accept => :json, :content_type => :json}
      log "RestParams: #{rest_params.inspect}" if verbose
      if %{put post}.include?(method)
        return result["message"] = "ERROR - no data param for post" if data == ""
        #response = RestClient.put url, data.to_json, rest_params if method == "put"
        response = RestClient::Request.new(rest_params).execute
        #response = RestClient.post url, data.to_json, rest_params if method == "post"
      else
        #response = RestClient.get url, rest_params
        response = RestClient::Request.new(rest_params).execute
      end
    rescue Exception => e
      result["message"] = e.message
      raise "RestError: #{result["message"]}" unless get_option(options, "suppress_errors") == true
      return result
    end
    log "Rest Response:\n#{response.inspect}" if verbose
    parsed_response = JSON.parse(response) rescue nil
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
    
  def split_nsh_path(path)
    result = ["",path]
    result[0] = path.split("/")[2] if path.start_with?("//")
    result[1] = path_from_nsh_path(path)
    result
  end

  # Separates the server and path from an NSH path
  #  offers the option of embedding a property (blade-style) in lieu of the base_path
  #
  # ==== Attributes
  #
  # * +path+ - the nsh path
  # * +base_path+ - a path fragment to substitute with a property
  # * +path_property+ - a property name
  #
  # ==== Returns
  #
  # * the path portion of the nsh path
  # * if a property_name is passed, the return is like this:
  #    /opt/bmc/RLM/??DEPLOY_VERSION??/appserver
  def path_from_nsh_path(path, base_path = nil, path_property = nil)
    result = path
    result = "/#{result.split("/")[3..-1].join("/")}" if result.start_with?("//")
    unless path_property.nil?
      result = result.gsub(base_path, "??#{path_property}??")
    end
    result
  end

  # Generates an NSH path for an uploaded attachment
  #
  # ==== Attributes
  #
  # * +attachment_local_path+ - the path to the uploaded attachment (from params)
  # * +brpm_hostname+ - blade server name of brpm host
  #
  # ==== Returns
  #
  # * nsh path
  # 
  def get_attachment_nsh_path(attachment_local_path, brpm_hostname)
    if attachment_local_path[1] == ":"
      attachment_local_path[1] = attachment_local_path[0]
      attachment_local_path[0] = '/'
    end
    attachment_local_path = attachment_local_path.gsub(/\\/, "/")
    "//#{brpm_hostname}#{attachment_local_path}"
  end

  # Generates a log formatted mesage
  #
  # ==== Attributes
  #
  # * +message+ - the path to the uploaded attachment (from params)
  # * +log_type+ - type of entry (DEBUG/WARN, etc)
  #
  # ==== Returns
  #
  # * message with timestamp and log type
  # 
  def log_message(message, log_type = "INFO")
    stamp = "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}|#{log_type}> "
    message = "" if message.nil?
    message = message.inspect unless message.is_a?(String)
    message.split("\n").map{|l| "#{stamp}#{l}"}.join("\n")
  end

  # Returns a timestamp to the thousanth of a second
  # 
  # ==== Returns
  #
  # string timestamp 20140921153010456
  #
  def precision_timestamp
    Time.now.strftime("%Y%m%d%H%M%S%L")
  end

  # Returns text with private values substituted
  # 
  # ==== Attributes
  #
  # * +txt+ - text to sanitize
  # ==== Returns
  #
  # string
  #
  def privatize(txt)
    return txt if @p_obj.nil?
    @p_obj.private_properties.each{|k,v| txt.gsub!(v,"-private-") }
    txt
  end
  
  # Creates a pid-file semaphore to govern global execution
  # 
  # ==== Attributes
  #
  # * +semaphore_key+ - string to name semaphore
  # ==== Returns
  #
  # true if semaphore created, false if already exists
  #
  def semaphore(semaphore_key)
    return false if @p_obj.nil?
    semaphore_dir = "#{p_obj.SS_automation_results_dir}/semaphores"
    semaphore_name = "#{semaphore_key}.pid"
    File.mkdir(semaphore_dir) unless File.exist?(semaphore_dir)
    return false if File.exist?(File.join(semaphore_dir, semaphore_name))
    fil = File.open(File.join(semaphore_dir, semaphore_name), "w+")
    fil.puts precision_timestamp
    fil.flush
    fil.close
    return true
  end
  
  # Clears a pid-file semaphore to govern global execution
  # 
  # ==== Attributes
  #
  # * +semaphore_key+ - string to name semaphore
  # ==== Returns
  #
  # true if semaphore deleted, false if it doesn't exist
  #
  def clear_semaphore(semaphore_key)
    semaphore_dir = "#{p_obj.SS_automation_results_dir}/semaphores"
    semaphore_name = "#{semaphore_key}.pid"
    return false unless File.exist?(File.join(semaphore_dir, semaphore_name))
    File.delete(File.join(semaphore_dir, semaphore_name))
    return true
  end
end

# Abstraction class for the step params
# provides convenience routines for working with params
class Param

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
  def get(key_name, default = nil)
    ans = ""
    ans = @json_params[key_name] if present_json?(key_name)
    ans = @params[key_name] if present_local?(key_name)
    ans = default if ans == "" && !default.nil?
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

  # Returns a hash with properties that are marked private
  # 
  # ==== Returns
  #
  # hash of properties
  #
  def private_properties
    return @private_props if defined?(@private_props)
    @private_props = {}
    @params.each{|k,v| @private_props[k.gsub("_encrypt","")] = @params[k.gsub("_encrypt","")] if k.end_with?("_encrypt") }
    @private_props
  end

  # Provides a logging style output
  #
  # ==== Attributes
  #
  # * +txt+ - the text to output
  # * +level+ - the log level [info, warn, ERROR]
  # * +output_file+ - an alternate output file to log to (default is step output)
  def log(txt, level = "INFO")
    puts log_message(txt, level)
    unless @output_file.nil?
      @fil = File.open(@output_file,"a") if @fil.nil?
      @fil.puts(log_message(txt, level))
      @fil.flush
      #fil.close
    end
  end

  def log_message(message, log_type = "INFO")
    stamp = "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}|#{log_type}> "
    message = "" if message.nil?
    message = message.inspect unless message.is_a?(String)
    message.split("\n").map{|l| "#{stamp}#{l}"}.join("\n")
  end

end

module Framework
  # Compatibility Routines
  def get_request_params
     none = "" # just so it doesn't  fail
  end

  def save_request_params
    @p.save_local_params
  end
  
end

# == Initialization on Include
# Objects are set for most of the classes on requiring the file
# these will be available in the BRPM automation
#  Customers should modify the BAA_BASE_PATH constant
# == Note the customer_include.rb reference.  To add your own routines and override methods use this file.
extend Framework
@request_params = {} if not defined?(@request_params)
@p = Param.new(@params, @request_params)
SS_output_file = @p.SS_output_file
@auto = BrpmAutomation.new(@p)
LibDir = File.expand_path(File.dirname(__FILE__))
require "#{LibDir}/lib/legacy_framework"
require "#{LibDir}/lib/baa"
require "#{LibDir}/lib/scm"
require "#{LibDir}/lib/rest"
require "#{LibDir}/lib/ticket"
require "#{LibDir}/lib/action"
customer_include_file = File.join(LibDir,"customer_include.rb")
if File.exist?(customer_include_file)
  @auto.log "Loading customer include file: #{customer_include_file}"
  require customer_include_file
end
ARG_PREFIX = "ARG_" unless defined?(ARG_PREFIX)
@rest = BrpmRest.new(@p.SS_base_url)
@request_params = @p.get_local_params
@params["direct_execute"] = true #Set to exclude capistrano
global_timestamp


