################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2012
# All Rights Reserved.
################################################################################

# ----------- Includes ---------------------#
require 'rubygems'
require 'net/http'
require 'uri'
require 'yaml'
require 'fileutils'
require 'cgi'
require 'json'
require 'timeout'
require 'rest-client'

KEYWORD_SWITCHES = ["RPM_PARAMS_FILTER","RPM_SRUN_WRAPPER","RPM_INCLUDE"] unless defined?(KEYWORD_SWITCHES)

module AutomationHeader
  def load_helper(lib_path)
    require "#{lib_path}/script_helper.rb"
    require "#{lib_path}/file_in_utf.rb"
  end

  # BJB 7/6/2010 Append a user script to the bottom of this one for cap execution
  def load_input_params(in_file)
    params = YAML::load(File.open(in_file))
    load_helper(params["SS_script_support_path"])
    @params = strip_private_flag(params)
    #BJB 11-10-14 Intercept to load framework
    initialize_framework
    @params
  end

  def get_param(key_name)
    @params.has_key?(key_name) ? @params["key_name"] : ""
  end

  def output_separator(phrase)
    divider = "==========================================================="
    "\n#{divider.slice(0..20)} #{phrase} #{divider.slice(0..(divider.length-phrase.length))}\n"
  end

  def write_to(message, newline = true)
    return if message.nil?
    sep = newline ? "\n" : ""
    @hand.print(message + sep)
    @hand.flush
    print(message + sep)
  end

  def create_output_file(params)
    init_log_file(params)
  end
  
  def init_log_file(params)
    @output_file = params["SS_output_file"]
    @hand = FileInUTF.open(@output_file, "a")
  end

  def run_command(params, command, arguments = nil, b_quiet = false)
    command = command.is_a?(Array) ? command.flatten.first : command
    command = "#{command} #{arguments}" unless arguments.nil?
    #command += exit_code_failure(params)
    @rpm.message_box "Run command: #{command}" unless b_quiet
    if params.has_key?("SS_capistrano") #["direct_execute"].nil?
      cmd_result = @rpm.execute_capistrano(command)  
    else # Direct Execute the command
      cmd_result = @rpm.execute_shell(command)
    end
    data_returned = @rpm.display_result(cmd_result)
    data_returned = CGI::escapeHTML(data_returned)
    @rpm.log data_returned  unless b_quiet
    @rpm.message_box("Results End")  unless b_quiet
    return data_returned
  end

  def get_server_list(params)
    rxp = /server\d+_/
    slist = {}
    lastcur = -1
    curname = ""
    params.sort.reject{ |k| k[0].scan(rxp).empty? }.each_with_index do |server, idx|
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
    return slist
  end

  def get_servers_by_property_value(prop_name, value, servers = nil)
    servers = get_server_list(@params) if servers.nil?
    hosts = []
    servers.each_with_index do |server, idx|
      server[1].each do |prop, val|
        hosts << server if (prop.downcase == prop_name.downcase && val.downcase.include?(value.downcase))
      end
    end
    hosts
  end

  def get_selected_hosts(server_list = nil)
    serverlist = get_server_list(@params) if serverlist.nil?
    hosts = server_list.map{ |srv| srv[0] }
  end

  def get_integration_details(details_yml)
    # SS_integration_details = "Project: TST\nDefault item: lots of stuff\n"
    ans = {}
    lines = details_yml.split("\n")
    itemcnt = 1
    lines.each do |item|
      it = item.split(": ")
      ans[it[0]] = it[1] if it.size == 2
      ans["item_#{itemcnt.to_s}"] = it[0] unless it.size == 2
      itemcnt += 1
    end
    ans
  end

  def set_property_flag(prop, value = nil)
    acceptable_fields = ["name", "value", "environment", "component", "global", "private"]
    flag = "#------ Block to Set Property ---------------#\n"
    if value.nil?
      flag += set_build_flag_data("properties", prop, acceptable_fields)
    else
      flag += "$$SS_Set_property{#{prop}=>#{value}}$$"
    end
    flag += "\n#------- End Set Property ---------------#\n"
    write_to flag
    flag
  end

  def set_server_flag(servers)
    # servers = "server_name, env\ncserver2_name, env2"
    acceptable_fields = ["name", "environment", "group"]
    flag = "#------ Block to Set Servers ---------------#\n"
    flag += set_build_flag_data("servers", servers, acceptable_fields)
    flag += "\n#------ End Set Servers ---------------#\n"
    write_to flag
    flag
  end

  def set_component_flag(components)
    # comps = "comp_name, version\ncomp2_name, version2"
    flag = "#------ Block to Set Components ---------------#\n"
    acceptable_fields = ["name", "version", "environment", "application"]
    flag += set_build_flag_data("components", components, acceptable_fields)
    flag += "\n#------ End Set Components ---------------#\n"
    write_to flag
    flag
  end

  def set_titles_acceptable?(cur_titles, acceptable_titles)
    cur_titles.each.reject{ |cur| acceptable_titles.include?(cur)}.count == 0
  end

  def set_build_flag_data(set_item, set_data, acceptable_titles)
    flag = ""; msg = ""
    lines = set_data.split("\n")
    titles = lines[0].split(",").map{ |it| it.strip }
    if set_titles_acceptable?(titles, acceptable_titles)
      flag += "$$SS_Set_#{set_item}{\n"
      flag += "#{titles.join(", ")}\n"
      lines[1..-1].each do |line|
        if line.split(",").count == titles.count
          flag += "#{line}\n" 
        else
          msg += "Skipped: #{line}"
        end
      end
      flag += "}$$\n"
    else
      flag += "ERROR - Unable to set #{set_item} - improper format\n"
    end
    flag += msg
  end

  def set_application_version(prop, value)
    # set_application_flag(app_name, version)
    flag = "#------ Block to Set Application Version ---------------#\n"
    flag += "$$SS_Set_application{#{prop}=>#{value}}$$"
    flag += "\n#------ End Set Application ---------------#\n"
    write_to(flag)
    flag
  end

  def pack_response(argument_name, response)
    flag = "#------ Block to Set Pack Response ---------------#\n"
    unless argument_name.nil?    
      if response.is_a?(Hash)
        # Used for out-table output parameter
        flag += "$$SS_Pack_Response{#{argument_name}@@#{response.to_json}}$$"
      else
        flag += "$$SS_Pack_Response{#{argument_name}=>#{response}}$$"
      end        
    end
    flag += "\n#------- End Set Pack Response Block ---------------#\n"
    write_to flag
    flag
  end


  def hostname_from_url(url)
    url_frag = url.split(":")
    url = url_frag.size > 1 ? url_frag[1] : url_frag[0]
    url.gsub("//","")
  end


  def fetch_url(path, testing=false)
    ss_url = @params["SS_base_url"] #  Leave this alone  
    tmp = (path.include?("://") ? path : "#{ss_url}/#{path}").gsub(" ", "%20").gsub("&", "&amp;")
    jobUri = URI.parse(tmp)
    puts "Fetching: #{jobUri}"
    request = Net::HTTP.get(jobUri) unless testing
  end

  def read_shebang(os_platform, action_txt)
    if os_platform.downcase =~ /win/
      result = {"ext" => ".bat", "cmd" => "cmd /c", "shebang" => ""}
    else
      result = {"ext" => ".sh", "cmd" => "/bin/bash ", "shebang" => ""}
    end
    if action_txt.include?("#![") # Custom shebang
      shebang = action_txt.scan(/\#\!.*/).first
      result["shebang"] = shebang
      items = shebang.scan(/\#\!\[.*\]/)
      if items.size > 0
        ext = items[0].gsub("#![","").gsub("]","")
        result["ext"] = ext if ext.start_with?(".")
        result["cmd"] = shebang.gsub(items[0],"").strip
      else
        result["cmd"] = shebang
      end      
    elsif action_txt.include?("#!/") # Basic shebang
      result["shebang"] = "standard"
    else # no shebang
      result["shebang"] = "none"
    end
    result
  end
  
  # Pretty display of cmd_result object
  #
  # ==== Attributes
  #
  # * +cmd_result+ - hash of results e.g. {"stdout" => "results", "stderr" => "", "pid" => "10245"}
  # ==== Returns
  #
  # * text output of result
  def display_result(cmd_result)
    return "No results" if cmd_result.nil?
    result = ""
    result = "ExitCode: #{cmd_result["status"]} - " if cmd_result.has_key?("status")
    result += "Process: #{cmd_result["pid"]}\nSTDOUT:\n#{cmd_result["stdout"]}\n"
    result = "STDERR:\n #{cmd_result["stderr"]}\n#{result}" if cmd_result["stderr"].length > 2
    result
  end

    
  def get_keyword_items(script_content = nil)
    result = {}
    content = script_content unless script_content.nil?
    content = File.open(@params["SS_script_file"]).read if script_content.nil?
    KEYWORD_SWITCHES.each do |keyword|
      reg = /\$\$\{#{keyword}\=.*\}\$\$/
      items = content.scan(reg)
      items.each do |item|
        result[keyword] = item.gsub("$${#{keyword}=","").gsub("}$$","").chomp("\"").gsub(/^\"/,"")
      end
    end
    result
  end
  
  def initialize_framework
    # Create a new output file and note it in the return message: sets @hand
    init_log_file(@params)
    @rpm = BrpmFramework.new(@params)
  end

end

# The base class for automation
# Provides convenience routines for working in BRPM
class BrpmFramework
  EXIT_CODE_FAILURE = 'Exit_Code_Failure' unless defined?(EXIT_CODE_FAILURE)

  include AutomationHeader
  
  # Initialize an instance of the class
  #
  # ==== Attributes
  #
  # * +params+ - the automation params hash
  def initialize(params)
    @fil = nil
    @params = params
    @base_rpm_url = @params["SS_base_url"]
    @token = defined?(AUTOMATION_API_TOKEN) ? AUTOMATION_API_TOKEN : @params["SS_api_token"]
    @output_file = @params["SS_output_file"]
    load_helper(@params["SS_script_support_path"])
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

  # Provides a simple failsafe for working with params
  # returns "" if the option doesn't exist or is blank
  # ==== Attributes
  #
  # * +options+ - the hash
  # * +key+ - key to find in options
  # * +default_value+ - if entered will be returned if the option doesn't exist or is blank
  def get_param(key, default_value = "")
    val = get_option(@params, key, default_value)
    complex_property_value(val)
  end

  # Throws an error if an param is missing
  #  great for checking if properties exist
  #
  # ==== Attributes
  #
  # * +options+ - the options hash
  # * +key+ - key to find
  def required_param(key)
    val = required_option(@params, key)
    complex_property_value(val)
  end

  # Shorthand for getting a param
  #  get a property by @rpm["prop_name"]
  #
  # ==== Attributes
  #
  # * +key+ - the key to find
  def [](key)
    get_param(key)
  end

  # Returns all params
  def params
    @params
  end

  # Adds a param
  #
  # ==== Attributes
  #
  # * +key+ - key to add
  # * +val+ - value to associate with key
  def add_param(key, val)
    @params[key] = val
  end
  
  # Removes a param
  #
  # ==== Attributes
  #
  # * +key+ - key to remove
  def remove_param(key)
    @params.delete(key)
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
      value = get_param(prop_name)
      result.gsub!("\${#{prop_name}}",value) unless value == ""
    end
    result
  end

  # Takes the command result from run command and build a pretty display
  #
  # ==== Attributes
  #
  # * +cmd_result+ - the command result hash
  # ==== Returns
  #
  # * formatted text
  def display_result(cmd_result)
    result = "Process: #{cmd_result["pid"]}\nSTDOUT:\n#{cmd_result["stdout"]}\n"
    result = "STDERR:\n #{cmd_result["stderr"]}\n#{result}" if cmd_result["stderr"].length > 2
    result += "#{EXIT_CODE_FAILURE} Command returned: #{cmd_result["status"]}" if cmd_result["status"] != 0
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
        response = RestClient::Request.new(rest_params).execute
      else
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

  # Returns the dos path from an nsh path
  #
  # ==== Attributes
  #
  # * +source_path+ - path in nsh
  #
  # ==== Returns
  #
  # * dos compatible path
  #
  def dos_path(source_path)
    path = ""
    return source_path if source_path.include?(":\\")
    path_array = source_path.split("/")
    if path_array[1].length == 1 # drive letter
      path = "#{path_array[1]}:\\"
      path += path_array[2..-1].join("\\")
    else
      path += path_array[1..-1].join("\\")
    end
    path
  end

  # Returns the nsh path from a dos path
  #
  # ==== Attributes
  #
  # * +source_path+ - path in nsh
  # * +server+ - optional, adds a server in nsh format
  #
  # ==== Returns
  #
  # * nsh compatible path
  #
  def nsh_path(source_path, server = nil)
    path = ""
    if source_path.include?(":\\")
      path_array = source_path.split("\\")
      path = "/#{path_array[0].gsub(":","/")}"
      path += path_array[1..-1].join("/")
    else
      path = source_path
    end
    path = "//server#{path}" unless server.nil?
    path.chomp("/")
  end
  
  # Executes a command via shell
  #
  # ==== Attributes
  #
  # * +command+ - command to execute on command line
  # ==== Returns
  #
  # * command_run hash {stdout => <results>, stderr => any errors, pid => process id, status => exit_code}
  def execute_shell(command)
    cmd_result = {"stdout" => "","stderr" => "", "pid" => "", "status" => 1}
    cmd_result["stdout"] = "Running #{command}\n"
    output_dir = File.join(@params["SS_output_dir"],"#{precision_timestamp}")
    errfile = "#{output_dir}_stderr.txt"
    command = "#{command} 2>#{errfile}#{exit_code_failure}"
    fil = File.open(errfile, "w+")
    fil.close    
    cmd_result["stdout"] += "Script Output:\n"
    begin
      orig_stderr = $stderr.clone
      cmd_result["stdout"] += `#{command}`
      status = $?
      cmd_result["pid"] = status.pid
      cmd_result["status"] = status.to_i
      stderr = File.open(errfile).read
      cmd_result["stderr"] = stderr if stderr.length > 2
    rescue Exception => e
      cmd_result["stderr"] = "ERROR\n#{e.message}\n#{e.backtrace}"
    end
    File.delete(errfile)
    cmd_result
  end
  
  # Executes the current script in Capistrano
  # gathers all inputs needed from params
  # ==== Returns
  #
  # command output and errors
  def execute_capistrano(command)
    cmd_result = {"stdout" => "","stderr" => "", "pid" => "", "status" => 1}
    show_errors = @params.has_key?("ignore_exit_codes") ? !(@params["ignore_exit_codes"] == 'yes') : false
    use_sudo = @params["sudo"].nil? ? "no" : @params["sudo"]
    set :user, @params["user"] unless @params["user"].nil?
    set :password, @params["password"] unless @params["password"].nil?
    cmd_result["stdout"] = "Execute via Capistrano\n"
    first_time = true
    rescue_cap_errors(show_errors) do
      run "#{use_sudo == 'yes' ? sudo : '' } #{command}", :pty => (use_sudo == 'yes') do |ch, str, data|
      # santize data returned so it can't affect the html
        data = CGI::escapeHTML(data)
        if str == :out
          if first_time
            cmd_result["stdout"] += data
            first_time = false
          else
            if cmd_result["stdout"].length > 30000
              cmd_result["stdout"].slice!(data.length..cmd_result["stdout"].length)
              cmd_result["stdout"] += output_separator("Data Truncated")
            end
            cmd_result["stdout"] += data
          end
        elsif str == :err
          cmd_result["stderr"] = data if data.length > 4
        end
      end
    end
    cmd_result["status"] = 0
    cmd_result
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
    if true #@output_file.nil?
      @fil = FileInUTF.open(@output_file,"a") if @fil.nil?
      @fil.puts(log_message(safe_txt, level))
      @fil.flush
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
    stamp = "#{Time.now.strftime("%H:%M:%S")}|#{log_type}> "
    message = "" if message.nil?
    message = message.inspect unless message.is_a?(String)
    message = privatize(message)
    message.split("\n").map{|l| "#{l.length == 0 ? "" : stamp}#{l}"}.join("\n")
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
    private_properties unless defined?(@private_props)
    @private_props.each{|v| txt.gsub!(v,"-private-") }
    txt.gsub!(decrypt_string_with_prefix(SS_integration_password_enc), "-private-") if defined?(SS_integration_password)
    txt
  end

  # Returns an array with property values that are marked private
  #  initializes array if it doesn't exist
  # ==== Returns
  #
  # array of values
  #
  def private_properties(private_value = nil)
    if private_value.nil?
      return @private_props if defined?(@private_props)
    end
    unless defined?(@private_props)  
      @private_props = []
      @params.each{|k,v| @private_props << @params[k.gsub("_encrypt","")] if k.end_with?("_encrypt") }
    end
    @private_props << private_value unless private_value.nil?
    private_value.nil? ? @private_props : true
  end

  # Performs a get on the passed model
  #
  # ==== Attributes
  #
  # * +model_name+ - rpm model [requests, plans, steps, version_tags, etc]
  # * +model_id+ - id of a specific item in the model (optional)
  # * +options+ - hash of options includes
  #    +filters+ - string of the filter text: filters[login]=bbyrd
  #    includes all the rest_call options
  #
  # ==== Returns
  #
  # * hash of http response
  def rpm_get(model_name, model_id = nil, options = {})
    url = rest_url(model_name, model_id) if get_option(options, "filters") == ""
    url = rest_url(model_name, nil, options["filters"]) if get_option(options, "filters") != ""
    result = rest_call(url, "get", options)
  end
  
  # Performs a put on the passed model
  #  use this to update a single record
  # ==== Attributes
  #
  # * +model_name+ - rpm model [requests, plans, steps, version_tags, etc]
  # * +model_id+ - id of a specific item in the model (optional)
  # * +data+ - hash of the put data
  # * +options+ - hash of options includes
  #    includes all the rest_call options
  #
  # ==== Returns
  #
  # * hash of http response
  def rpm_update(model_name, model_id, data, options = {})
    url = rest_url(model_name, model_id)
    options["data"] = data
    result = rest_call(url, "put", options)
    result
  end
  
  # Performs a post on the passed model
  #  use this to create a new record
  # ==== Attributes
  #
  # * +model_name+ - rpm model [requests, plans, steps, version_tags, etc]
  # * +data+ - hash of the put data
  # * +options+ - hash of options includes
  #    includes all the rest_call options
  #
  # ==== Returns
  #
  # * hash of http response
  def rpm_create(model_name, data, options = {})
    options["data"] = data
    url = rest_url(model_name)
    result = rest_call(url, "post", options)
    result
  end

  # Sends an email based on step recipients
  #
  # ==== Attributes
  #
  # * +subject+ - text of email subject
  # * +body+ - text of email body
  #
  # ==== Returns
  #
  # * empty string
  def notify(body, subject = "Mail from automation")
    url = "#{@base_rpm_url}/v1/steps/#{@params["step_id"]}/notify?token=#{@token}"
    data = {"filters"=>{"notify"=>{"body"=> body, "subject"=> subject}}}
    result = rest_call(url, "get", {"data" => data})
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

  # Sets the token for rest interactions
  # 
  # ==== Attributes
  #
  # * +token+ - token for RPM rest
  #
  def set_token(token)
    @token = token
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
    semaphore_dir = "#{@params["SS_automation_results_dir"]}/semaphores"
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
    semaphore_dir = "#{@params["SS_automation_results_dir"]}/semaphores"
    semaphore_name = "#{semaphore_key}.pid"
    return false unless File.exist?(File.join(semaphore_dir, semaphore_name))
    File.delete(File.join(semaphore_dir, semaphore_name))
    return true
  end
  
  # Checks/Creates a staging directory
  # 
  # ==== Attributes
  #
  # * +force+ - forces creation of the path if it doesnt exist
  # ==== Returns
  #
  # staging path or ERROR_ if force is false and path does not exist
  #  
  def get_staging_dir(version, force = false)
    pattern = File.join(RPM_STAGING_PATH, "#{Time.now.year.to_s}", path_safe(get_param("SS_application")), path_safe(get_param("SS_component")), path_safe(version))
    if force
      FileUtils.mkdir_p(pattern)
    else
      return pattern if File.exist?(pattern) # Cannot stage the same files twice
      return "ERROR_#{pattern}"
    end
    pattern
  end
  
  # Returns a version of the string safe for a filname or path
  def path_safe(txt)
    txt.gsub(" ", "_").gsub(/\,|\[|\]/,"")
  end

  # Servers in params need to be filtered by OS
  def get_platform_servers(os_platform)
    servers = get_server_list(@params)
    result = servers.select{|k,v| v["os_platform"].downcase =~ /#{os_platform}/ }
  end

  # Builds a hash of servers and properties from params
  # 
  # ==== Attributes
  #
  # * +params+ - optional, defaults to the @params from step
  # ==== Returns
  #
  # Hash of servers and properties, like this:
  # servers = {"ip-172-31-36-115.ec2.internal"=>{"dns"=>"ip-172-31-36-115.ec2.internal", "ip_address"=>"", "os_platform"=>"Linux", "CHANNEL_ROOT"=>"/mnt/deploy"}, 
  # "ip-172-31-45-229.ec2.internal"=>{"dns"=>"ip-172-31-45-229.ec2.internal", "ip_address"=>"", "os_platform"=>"Linux", "CHANNEL_ROOT"=>"/mnt/deploy"}}
  #  
  def get_server_list(params = @params)
    rxp = /server\d+_/
    slist = {}
    lastcur = -1
    curname = ""
    params.sort.reject{ |k| k[0].scan(rxp).empty? }.each_with_index do |server, idx|
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
    return slist
  end

  private
  
  def exit_code_failure
    size_ = EXIT_CODE_FAILURE.size
    exit_code_failure_first_part  = EXIT_CODE_FAILURE[0..3]
    exit_code_failure_second_part = EXIT_CODE_FAILURE[4..size_]
    @params['ignore_exit_codes'] == 'yes' ?
      '' :
      "; if [ $? -ne 0 ]; then first_part=#{exit_code_failure_first_part}; echo \"${first_part}#{exit_code_failure_second_part}\"; fi;"
  end

  
  def url_encode(name)
    name.gsub(" ","%20").gsub("/","%2F").gsub("?","%3F")
  end
    
  def rest_url(model_name, id = nil, filters = nil)
    url = "#{@base_rpm_url}/v1/#{model_name}#{id == nil ? "" : "/#{id}" }"
    url += "?#{filters}&token=#{@token}" if filters
    url += "?token=#{@token}" unless filters
    url
  end
   
  def touch_file(file_path)
    fil = File.open(file_path,"w+")
    fil.close
    file_path
  end
  
  def rescue_cap_errors(show_errors, &block)
    begin
      yield
    rescue RuntimeError => failure
      if show_errors
        write_to "SSH-Capistrano_Error: #{failure.message}\n#{failure.backtrace}"
        write_to(EXIT_CODE_FAILURE) 
      end
    end
  end
  
end

# Wrapper class for NSH interactions
class NSHTransport < BrpmFramework

  attr_writer :test_mode

  # Initialize the class
  #
  # ==== Attributes
  #
  # * +nsh_path+ - path to NSH dir on files system (must contain br directory too)
  # * +options+ - hash of options to use, send "output_file" to point to the logging file
  # * +test_mode+ - true/false to simulate commands instead of running them
  #
  def initialize(nsh_path, params, options = {}, test_mode = false)
    @nsh_path = nsh_path
    @test_mode = test_mode
    @verbose = get_option(options, "verbose", false)
    super(params) unless params.nil?
    @opts = options
    @run_key = get_option(options,"timestamp",Time.now.strftime("%Y%m%d%H%M%S"))
    outf = get_option(options,"output_file", SS_output_file)
    @output_dir = File.dirname(outf)
    insure_proxy
  end

  # Verifies that proxy cred is set
  #
  # ==== Returns
  #
  # * blcred cred -acquire output
  def insure_proxy
    return true if get_option(@opts, "bl_profile") == ""
    res = get_cred
    puts res
  end

  # Displays any errors from a cred status
  #
  # ==== Attributes
  #
  # * +status+ - output from cred command
  #
  # ==== Returns
  #
  # * true/false
  def cred_errors?(status)
    errors = ["EXPIRED","cache is empty"]
    errors.each do |err|
        return true if status.include?(err)
    end
    return false
  end

  # Performs a cred -acquire
  #
  # ==== Returns
  #
  # * cred result message
  def get_cred
    bl_cred_path = File.join(@nsh_path,"bin","blcred")
    cred_status = `#{bl_cred_path} cred -list`
    puts "Current Status:\n#{cred_status}" if @test_mode
    if (cred_errors?(cred_status))
      # get cred
      cmd = "#{bl_cred_path} cred -acquire -profile #{get_option(@opts,"bl_profile")} -username #{get_option(@opts,"bl_username")} -password #{get_option(@opts,"bl_password")}"
      res = execute_shell(cmd)
      puts display_result(res) if @test_mode
      result = "Acquiring new credential"
    else
      result = "Current credential is valid"
    end
    result
  end

  # Runs an nsh script
  #
  # ==== Attributes
  #
  # * +script_path+ - path (local to rpm server) to script file
  #
  # ==== Returns
  #
  # * results of script
  def nsh(script_path, raw_result = false)
    cmd = "#{@nsh_path}/bin/nsh #{script_path}"
    cmd = @test_mode ? "echo \"#{cmd}\"" : cmd
    result = execute_shell(cmd)
    return result if raw_result
    display_result(result)
  end

  # Runs a simple one-line command in NSH
  #
  # ==== Attributes
  #
  # * +command+ - command to run
  #
  # ==== Returns
  #
  # * results of command
  def nsh_command(command, raw_result = false)
    path = create_temp_script("echo Running #{command}\n#{command}\n",{"temp_path" => "/tmp"})
    result = nsh(path, raw_result)
    File.delete path unless @test_mode
    result
  end

  # Copies all files (recursively) from source to destination on target hosts
  #
  # ==== Attributes
  #
  # * +target_hosts+ - blade hostnames to copy to
  # * +src_path+ - NSH path to source files (may be an array)
  # * +target_path+ - path to copy to (same for all target_hosts)
  #
  # ==== Returns
  #
  # * results of command
  def ncp(target_hosts, src_path, target_path)
    #ncp -vr /c/dev/SmartRelease_2/lib -h bradford-96204e -d "/c/dev/BMC Software/file_store"
    src_path = src_path.join(" ") if src_path.is_a?(Array)
    cmd = "#{@nsh_path}/bin/ncp -vrA #{src_path} -h #{target_hosts.join(" ")} -d \"#{target_path}\"" unless target_hosts.nil?
    cmd = "#{@nsh_path}/bin/cp -vr #{src_path} #{target_path}" if target_hosts.nil?
    cmd = @test_mode ? "echo \"#{cmd}\"" : cmd
    log cmd if @verbose
    result = execute_shell(cmd)
    display_result(result)
  end

  # Runs a command via nsh on a windows target
  #
  # ==== Attributes
  #
  # * +target_hosts+ - blade hostnames to copy to
  # * +target_path+ - path to copy to (same for all target_hosts)
  # * +command+ - command to run
  #
  # ==== Returns
  #
  # * results of command per host
  def nexec_win(target_hosts, target_path, command)
    # if source_script exists, transport it to the hosts
    result = "Running: #{command}\n"
    target_hosts.each do |host|
      cmd = "#{@nsh_path}/bin/nexec #{host} cmd /c \"cd #{target_path}; #{command}\""
      cmd = @test_mode ? "echo \"#{cmd}\"" : cmd
      result += "Host: #{host}\n"
      res = execute_shell(cmd)
      result += display_result(res)
    end
    result
  end

  # Runs a script on a remote server via NSH
  #
  # ==== Attributes
  #
  # * +target_hosts+ - blade hostnames to copy to
  # * +script_path+ - nsh path to the script
  # * +target_path+ - path from which to execute the script on the remote host
  # * +options+ - hash of options (raw_result = true)
  #
  # ==== Returns
  #
  # * results of command per host
  def script_exec(target_hosts, script_path, target_path, options = {})
    raw_result = get_option(options,"raw_result", false)
    script_dir = File.dirname(script_path)
    err_file = touch_file("#{script_dir}/nsh_errors_#{Time.now.strftime("%Y%m%d%H%M%S%L")}.txt")
    cmd = "#{@nsh_path}/bin/scriptutil -d \"#{target_path}\" -h #{target_hosts.join(" ")} -H \"Results from: %h\" -s #{script_path} 2>#{err_file}"
    result = execute_shell(cmd)
    result["stderr"] = "#{result["stderr"]}\n#{File.open(err_file).read}"
    result = display_result(result) unless raw_result
    result
  end

  # Executes a text variable as a script on remote targets
  #
  # ==== Attributes
  #
  # * +target_hosts+ - array of target hosts
  # * +script_body+ - body of script
  # * +target_path+ - path on targets to store/execute script
  #
  # ==== Returns
  #
  # * output of script
  #
  def script_execute_body(target_hosts, script_body, target_path, options = {})
    script_file = "nsh_script_#{Time.now.strftime("%Y%m%d%H%M%S")}.sh"
    full_path = "#{File.dirname(SS_output_file)}/#{script_file}"
    fil = File.open(full_path,"w+")
    #fil.write script_body.gsub("\r", "")
    fil.flush
    fil.close
    result = script_exec(target_hosts, full_path, target_path, options)
  end

  # Runs a simple ls command in NSH
  #
  # ==== Attributes
  #
  # * +nsh_path+ - path to list files
  #
  # ==== Returns
  #
  # * array of path contents
  def ls(nsh_path)
    res = nsh_command("ls #{nsh_path}")
    res.split("\n").reject{|l| l.start_with?("Running ")}
  end

  # Provides a host status for the passed targets
  #
  # ==== Attributes
  #
  # * +target_hosts+ - array of hosts
  #
  # ==== Returns
  #
  # * hash of agentinfo on remote hosts
  def status(target_hosts)
    result = {}
    target_hosts.each do |host|
      res = nsh_command("agentinfo #{host}")
      result[host] = res
    end
    result
  end


  private

  def create_temp_script(body, options)
    script_type = get_option(options,"script_type", "nsh")
    base_path = get_option(options, "temp_path")
    tmp_file = "#{script_type}_temp_#{precision_timestamp}.#{script_type}"
    full_path = "#{base_path}/#{tmp_file}"
    fil = File.open(full_path,"w+")
    fil.puts body
    fil.flush
    fil.close
    full_path
  end

end

extend AutomationHeader
results = "Error in command"
# Load the input parameters file and parse as yaml.
ss_input_file = "$$SS_INPUT_FILE$$"

