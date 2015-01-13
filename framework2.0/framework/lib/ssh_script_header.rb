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
require 'popen4'
require 'cgi'
require 'json'
require 'timeout'
require 'rest-client'

KEYWORD_SWITCHES = ["RPM_PARAMS_FILTER","RPM_SRUN_WRAPPER","RPM_INCLUDE"] unless defined?(KEYWORD_SWITCHES)
Windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/) unless defined?(Windows)

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
    cmd_result = @rpm.execute_shell(command)
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

  def get_integration_details(key, details_yml = nil)
    details_yml = SS_integration_details if details_yml.nil?
    # SS_integration_details = "Project: TST\nDefault item: lots of stuff\n"
    details = YAML.load(details_yml)
    details[key]
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
  
  def initialize_framework
    # Create a new output file and note it in the return message: sets @hand
    init_log_file(@params)
    @rpm = BrpmAutomation.new(@params)
    if @params["SS_script_type"] != 'test' && @params["SS_script_target"] != "resource_automation" && !@params.has_key?("SS_no_framework") 
      automation_settings = @params["SS_script_support_path"].gsub("lib/script_support","config/automation_settings.rb")
      require "#{automation_settings}" if File.exist?(automation_settings)    
      f_dir = defined?(FRAMEWORK_DIR) ? FRAMEWORK_DIR : @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib")
      require "#{f_dir}/brpm_framework"
    end
  end

end

# The base class for automation
# Provides convenience routines for working in BRPM
class BrpmAutomation
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
    result = options.has_key?(key) ? options[key] : nil
    result = default_value if result.nil? || result == ""
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

  # Gets a params
  #
  # ==== Attributes
  #
  # * +key+ - key to find
  def get_param(key, default_value = "")
    result = get_option(@params, key, default_value)
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
    verbose = get_option(options, "verbose") == "yes" or get_option(options, "verbose")
    headers = get_option(options, "headers", {:accept => :json, :content_type => :json})
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
      rest_params[:headers] = headers
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

  # Returns the dos path from a standard path
  #
  # ==== Attributes
  #
  # * +source_path+ - path in standard "/" format
  # * +drive_letter+ - base drive letter if not included in path (defaults to C)
  #
  # ==== Returns
  #
  # * dos compatible path
  #
  def dos_path(source_path, drive_letter = "C")
    path = ""
    return source_path if source_path.include?(":\\")
    path_array = source_path.split("/")
    if path_array[1].length == 1 # drive letter
      path = "#{path_array[1]}:\\"
      path += path_array[2..-1].join("\\")
    else
      path = "#{drive_letter}:\\"
      path += path_array[1..-1].join("\\")
    end
    path
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
    command = "#{command} 2>#{errfile}#{exit_code_failure}" unless Windows
    fil = File.open(errfile, "w+")
    fil.close    
    cmd_result["stdout"] += "Script Output:\n"
    begin
      cmd_result["stdout"] += `#{command}`
      status = $?
      cmd_result["pid"] = status.pid
      cmd_result["status"] = status.to_i
      fil = File.open(errfile)
      stderr = fil.read
      fil.close
      cmd_result["stderr"] = stderr if stderr.length > 2
    rescue Exception => e
      cmd_result["stderr"] = "ERROR\n#{e.message}\n#{e.backtrace}"
    end
    File.delete(errfile)
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
    FileUtils.mkdir(semaphore_dir) unless File.exist?(semaphore_dir)
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
  def semaphore_clear(semaphore_key)
    semaphore_dir = "#{@params["SS_automation_results_dir"]}/semaphores"
    semaphore_name = "#{semaphore_key}.pid"
    return false unless File.exist?(File.join(semaphore_dir, semaphore_name))
    File.delete(File.join(semaphore_dir, semaphore_name))
    return true
  end
  
  # Checks if a semaphore exists
  # 
  # ==== Attributes
  #
  # * +semaphore_key+ - string to name semaphore
  # ==== Returns
  #
  # true if semaphore exists, false if it doesn't exist
  #
  def semaphore_exists(semaphore_key)
    semaphore_dir = "#{@params["SS_automation_results_dir"]}/semaphores"
    semaphore_name = "#{semaphore_key}.pid"
    return true if File.exist?(File.join(semaphore_dir, semaphore_name))
    return false
  end
  
  # Waits a specified period for a semaphore to clear
  # throws error after wait time if semaphore does not clear
  # ==== Attributes
  #
  # * +semaphore_key+ - string to name semaphore
  # * +wait_time+ - time in minutes before failure (default = 15mins)
  # ==== Returns
  #
  # true if semaphore is cleared
  #
  def semaphore_wait(semaphore_key, wait_time = 15)
    interval = 20; elapsed = 0
    semaphore_dir = "#{@params["SS_automation_results_dir"]}/semaphores"
    semaphore_name = "#{semaphore_key}.pid"
    semaphore = File.join(semaphore_dir, semaphore_name)
    return true if !File.exist?(semaphore)
    until !File.exist?(semaphore) || (elapsed/60 > wait_time) do
      sleep interval
      elapsed += interval
    end
    if File.exist?(semaphore)
      raise "ERROR: Semaphore (#{semaphore}) still exists after #{wait_time} minutes"
    end
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
    staging_path = defined?(RPM_STAGING_PATH) ? RPM_STAGING_PATH : File.join(@params["SS_automation_results_dir"],"staging")
    pattern = File.join(staging_path, "#{Time.now.year.to_s}", path_safe(get_param("SS_application")), path_safe(get_param("SS_component")), path_safe(version))
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
   
  # Splits the server and path from an nsh path
  # returns same path if no server prepended
  # ==== Attributes
  #
  # * +path+ - nsh path
  # ==== Returns
  #
  # array [server, path] server is blank if not present
  #
  def split_nsh_path(path)
    result = ["",path]
    result[0] = path.split("/")[2] if path.start_with?("//")
    result[1] = "/#{path.split("/")[3..-1].join("/")}" if path.start_with?("//")  
    result
  end

  private
  
  def exit_code_failure
    return "" if Windows
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
   
  def touch_file(file_path)
    fil = File.open(file_path,"w+")
    fil.close
    file_path
  end
  
end


extend AutomationHeader
results = "Error in command"
# Load the input parameters file and parse as yaml.
ss_input_file = "$$SS_INPUT_FILE$$"

