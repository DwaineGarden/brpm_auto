
#---------------------- Methods -------------------------#

def get_other_request_params(other_request)
  # Uses a json document in automation_results to store free-form information
  request_data_file_dir = File.dirname(@params["SS_output_dir"])
  request_data_file_dir.gsub!("/#{@params["SS_request_number"]}","/#{other_request}")
  request_data_file = "#{request_data_file_dir}/request_data.json"
  request_params = JSON.parse(File.open(cur).read)
end

def update_other_request_params(request_id, updates = {})
  # Uses a json document in automation_results to store free-form information
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

def delay_sleep(cnt = 0)
  #  SleepDelay = [5,10,25,60]
  delay = (cnt > SleepDelay.size - 1) ? SleepDelay[-1] : SleepDelay[cnt]
  sleep(delay)
end

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
  @auto.log(res)

end

#---------------------- Database Methods -----------------------#

def init_brpm_db_connection
  # NOTE - may need additional drivers for your database
  require 'activerecord-jdbc-adapter'
  require 'active_record'
  if defined?(@params)
    fil = @params["SS_script_support_path"].gsub("/lib/script_support","") + "/config/database.yml"
  else
    fil = `pwd`.chomp + "/config/database.yml"
  end
  conts = File.open(fil).read
  dbs = YAML.load(conts)
  @db_connection = {
    :adapter => dbs["production"]["adapter"], 
    :username => dbs["production"]["username"], 
    :password => dbs["production"]["password"], 
    :host => dbs["production"]["host"], 
    :database => dbs["production"]["database"],
    :port => dbs["production"]["port"],
    :encoding => 'utf8',
    :pool => '12',
    :wait_timeout => '10'
  }
  ActiveRecord::Base.establish_connection(@db_connection)
end

#----------- BRPM REST Calls -------------------#


def application_info(options = {})
  # Returns route list for the request app
  @request = Request.new(@params["SS_base_url"], @param["request_id"])
  routes = {}
  envs = {}
  comps ={}
  result = @request.app_routes
  result.each do |route|
    routes[route["name"]] = route["id"]
  end
  app = @request.app
  app["components"].each do |component|
    comps[component["name"]] = component["id"]
  end
  app["environments"].each do |env|
    envs[env["name"]] = env["id"]
    result_env = @request.get("environments", env["id"])
    return "ERROR" if result_env.is_a?(String)
    envs["environment_type"] = result_env["environment_type"]
  end 
  {"routes" => routes, "environments" => envs, "components" => comps}
end

def ticket_exists(foreign_id, options = {})
  result = {}
  options["quiet"] = "yes"
  options["url_param"] = "filters[foreign_id]=#{foreign_id}"
  result = @rest.get("tickets", nil, options)
  return "ERROR" if result.is_a?(String)
  result
end

def monitor_request(request_id, options = {})
  target_status = "complete"
  token = @params["SS_api_token"] 
  token = options["token"] if options.has_key?("token")
  max_time = 15*60 # seconds = 15 minutes
  max_time = 60 * options["max_time"].to_i if options.has_key?("max_time")
  monitor_step_name = options.has_key?("monitor_step_name") ? options["monitor_step_name"] : "none"
  checking_interval = 15 #seconds
  if request_id.to_i > 0 && ["created","planned","started","problem","hold","complete"].include?(target_status)
      message_box("Montoring Request: #{request_id}","sep")
    req_status = "none"
    start_time = Time.now
    elapsed = 0
    until (elapsed > max_time || req_status == target_status)
      url = "#{@params["SS_base_url"]}/v1/requests/#{request_id}?token=#{token}"
      rest_result = rest_call(url, "get", {"quiet" => "yes"})
      @auto.log "\tREST Call: #{url}"
      unless rest_result["status"] == "success"
        req_status = "Command_Failed: Request not found"
        break
      end
      if monitor_step_name == "none"
        req_status = rest_result["response"]["aasm_state"]
      else
        found = false
        rest_result["response"]["steps"].each do |step|
          if step["name"] == monitor_step_name
            req_status = step["aasm_state"]
            found = true
            break
          end
        end
        unless found
          req_status = "Command_Failed: step not found"
          break
        end
      end
      if req_status == target_status
        break
      else
        @auto.log "\tWaiting(#{elapsed.floor.to_s}) - Current status: #{req_status}"
        sleep(checking_interval)
        elapsed = Time.now - start_time
      end
    end
    if req_status == target_status
      req_status =  "Success test, looking for #{success}: Success!"
    else
      if elapsed > max_time
        req_status =  "Command_Failed: Max time: #{max_time}(secs) reached.  Status is: #{req_status}, looking for: #{target_status}"
      else
        req_status = "REST call generated bad data, Status is: #{req_status}, looking for: #{target_status}"
      end
    end
  else
    req_status =  "Command_Failed: No Request_id specified"  
  end
  req_status
end

def create_version_tags(tag_info)
  # Meant to be called after importing a spreadsheet of versions
  # tag info should be an array of hashes [{ "application" => "app1",
  #                                       "component" => "database",
  #                                       "environment" => "UAT" could be "all",
  #                                       "name" => "1.2.1",
  #                                       "artifact_url" => "file:///home/brady/stuff"}]
  token = @params["SS_api_token"]
  token = Token if defined?(Token)
  results = {"status" => "failure", "message" => ""}
  message = "Processing tags: #{tag_info.size.to_s} to do\n"
  version_tag = { "name" => "", "artifact_url" => "", "find_application" => "", "find_component" => "", "active" => true}
  tag_info.each do |v_tag|
    if v_tag.has_key?("name")
      version_tag["find_application"] = v_tag["application"]
      version_tag["find_component"] = v_tag["component"]
      version_tag["find_environment"] = v_tag["environment"] unless v_tag["environment"] == "all"
      version_tag["name"] = v_tag["name"]
      version_tag["artifact_url"] = v_tag["artifact_url"]
      message += "adding #{v_tag["name"]} to #{v_tag["component"]}"
      url = "#{@params["SS_base_url"]}/v1/version_tags?token=#{token}"      
      result = rest_call(url, "POST", {"data" => {"version_tag" => version_tag}})
      message += ", Status: #{result["status"]}\n"
      results["response"] = result["response"]
      results["status"] = "Success" if result["status"] == "success"
    else
      message += "bad record: #{v_tag.inspect}\n"
    end
    version_tag.delete("find_environment") if version_tag.has_key?("find_environment")
  end
  results
end


def get_instance_id_from_version
  # artifact_url = "brpd://[#{package_id}]#{@package_name}/[#{instance_id}]#{@instance_name}"  
  result = {}
  items = @params["step_version_artifact_url"].split("/")
  if items.size < 3
    return result
  end
  result["package_id"] = items[2].split("]")[0].gsub("[","")
  result["package_name"] = items[2].split("]")[1]
  result["instance_id"] = items[3].split("]")[0].gsub("[","")
  result["instance_name"] = items[3].split("]")[1]
  result
end

def version_tag_exists(name)
  result = "Failed"
  url = "#{@params["SS_base_url"]}/v1/version_tags?filters[name]=#{url_encode(name)}&token=#{Token}"
  rest_result = rest_call(url, "get")
  if rest_result["status"] == "success"
    @auto.log "Tag Exists?: #{url}\nResult: #{rest_result["response"]}"
    result = rest_result["response"].first["id"]
  end
  result
end

def assign_version_tag_to_steps(version_tag, steps = [])
  result = "Error - failed to update steps"
  steps = steps_with_matching_component if steps.size == 0
  steps.each do |step|
    step_data = {"version_tag_id" => version_tag["id"], "component_version" => version_tag["name"]}
    url = "#{@params["SS_base_url"]}/v1/steps/#{step["id"]}?token=#{Token}"
    rest_result = rest_call(url, "PUT", {"data" => step_data})
    if rest_result["status"] == "success"
      @auto.log "Updating step: #{step["id"]}\nResult: #{rest_result["response"]}"
      result = "success"
    end
  end
  result
end

def version_tag_query(name, show_all = false)
  result = "Failed"
  url = "#{@params["SS_base_url"]}/v1/version_tags?filters[name]=#{url_encode(name)}&token=#{Token}"
  rest_result = rest_call(url, "get")
  if rest_result["status"] == "success"
    @auto.log "Tag Exists?: #{url}\nResult: #{rest_result["response"]}"
    result = rest_result["response"].first["id"]
  end
  show_all ? rest_result["response"] : result
end

def steps_with_matching_component(req = nil, comp = nil)
  req_id = req.nil? ? @params["request_id"].to_i - 1000 : req
  url = "#{@params["SS_base_url"]}/v1/steps?filters[request_id]=#{req_id.to_s}&token=#{Token}"
  cur_comp = comp.nil? ? @params["SS_component"] : comp
  rest_result = rest_call(url, "get")
  if rest_result["status"] != "success"
    return "Failed"
  end
  steps = []
  rest_result["response"].each do |step|
    steps << step if step["installed_component"] && cur_comp == step["installed_component"]["component"]["name"]
  end
  steps
end

#---------------------- Jenkins Methods -----------------------#
def jenkins_job_data
   options = {"username" => SS_hudson_username, "password" => SS_hudson_password}
   response = rest_call("#{BuildServerURL}/api/json", "get", options)
   data = response["status"] == "success" ? response["response"] : "#{response["status"]}: #{response["message"]}"
end

# return the status of a build
def jenkins_job_build_data(build_no = nil)
  build_no = "lastBuild" if build_no.nil?
  options = {"username" => SS_hudson_username, "password" => SS_hudson_password}
  response = rest_call("#{BuildServerURL}/#{build_no}/api/json", "get", options)
  data = response["status"] == "success" ? response["response"] : "#{response["status"]}: #{response["message"]}"
end

def jenkins_build_status(build_no = nil)
  response = jenkins_job_build_data(build_no)
  # Now parse for the status and build id
  #@auto.log "Raw Result: #{response.inspect}"
  ans = {}
  ans["still_building"] = response["building"]
  ans["success"] = response["result"]
  ans
end

def jenkins_build_results(build_no, get_link = false)
  url = "#{BuildServerURL}/#{build_no}/consoleText"
  response = get_link ? display_url(url) : send_request("get", url)
end

def jenkins_monitor_build(build_no)
  # start with an initial build result
  # Now parse for the status and build id
  max_time = MaxBuildTime
  sleep_interval = 15
  result = jenkins_build_status(build_no)
  results = "Initial test: Build Number: #{build_no}, Status - building: #{result["still_building"].to_s}, result: #{result["success"]}\n"
  # Now Check to see if the token matches
  build_match = true
  #build_match = response.include?(ss_token) if use_token_match # Enable this if using token matching
  @auto.log "#-------------------------------------------------------------#\n#   Monitoring Build Progress (id: #{build_no})"
  if build_no.to_i > 0 && result["still_building"] == true && build_match
    start_time = Time.now
    elapsed = 0
    complete = false
    until elapsed > (max_time * 60) do
      result = jenkins_build_status(build_no)
      results += "Status - building: #{result["still_building"].to_s}, result: #{result["success"]}\n"
      if result["still_building"] == false
        @auto.log "Success - #{result["success"]}"
        complete = true if result["success"] == "SUCCESS"
    complete = false if result["success"] != "SUCCESS"
        break
      else
        elapsed = Time.now - start_time
        @auto.log "Still building ...elapsed: #{elapsed.to_i.to_s}, pausing for #{sleep_interval.to_s} seconds"
        sleep sleep_interval
      end
      elapsed = Time.now - start_time
    end
  elsif  result["success"] != "SUCCESS"
    @auto.log "Build failed on initial parameters, either could not retrieve build id or token did not match output"
    complete = false
  else
    @auto.log "Build Successful"
    complete = true
  end
  complete
end

def jenkins_build(build_arguments = {})
  # Fetch the next build number
  build_details = jenkins_job_data
  next_build = build_details["nextBuildNumber"]
  url = "#{BuildServerURL}/build"
  options = {"username" => SS_hudson_username, "password" => SS_hudson_password, "data" => build_arguments}
  response = send_request("POST", url, build_arguments)
  #response = rest_call(url, "POST", options)
  last_build = next_build 
  result = "Web server response: " + response["header"]
  @auto.log result
  unless response["header"].include?("HTTPFound 302") #response["status"] == "failure"
    @auto.log "Command_Failed: Build did not launch"
    return -1
  end
  launched = false
  10.times do 
    test_result = jenkins_job_build_data(last_build)
    if test_result.is_a?(String) && test_result.include?("failure")
      @auto.log "Job not ready waiting..."
      sleep(6)
    else
      launched = true
      break
    end
  end
  if launched
    return last_build
  else
    @auto.log "Command_Failed: Build did not launch in 60 seconds"
    return -1
  end
end

#----------- RLM Routines ------------------#

def rpd_attach_logs(instance_id, command, result_dir, pack_response_argument)
  instance_logs = RlmUtilities.get_instance_logs(SS_integration_dns, SS_integration_username, SS_integration_password, instance_id, command)
  if instance_logs
    rlm_instance_logs = File.join(result_dir, "rlm_instance_logs")
    unless File.directory?(rlm_instance_logs)
      Dir.mkdir(rlm_instance_logs, 0700)
    end

    log_file_path = File.join(rlm_instance_logs, "#{instance_id}.txt")
    fh = File.new(log_file_path, "w")
    fh.write(instance_logs)
    fh.close

    pack_response pack_response_argument, log_file_path
  end 
end

def rpd_attach_deployment_logs(instance_id, result_dir, pack_response_argument)   
  instance_logs = RlmUtilities.get_deployment_logs(SS_integration_dns, SS_integration_username, SS_integration_password, instance_id)
  if instance_logs
    rlm_instance_logs = File.join(result_dir, "rlm_instance_logs")
    unless File.directory?(rlm_instance_logs)
      Dir.mkdir(rlm_instance_logs, 0700)
    end

    log_file_path = File.join(rlm_instance_logs, "#{instance_id}.txt")
    fh = File.new(log_file_path, "w")
    fh.write(instance_logs)
    fh.close

    pack_response pack_response_argument, log_file_path
  end 
end

def rpd_get_package_id(package_name)
  return(package_name) if package_name.to_i > 2
  rlm_packages = RlmUtilities.get_all_packages(SS_integration_dns, SS_integration_username, SS_integration_password).first
  rlm_packages.has_key?(package_name) ? rlm_packages[package_name].split("*")[0] : -1
end

def rpd_transfer_properties(package_id, prefixes = [], prop_type = "package")
  #instance property add <instance> <name> <value> [locked]
  component = @params["SS_component"]
  begin
    @params.each_pair do |prop,val|
      prefixes.each do |prefix|
        if prop.start_with?(prefix) && !val.nil? && val.length > 0
          @auto.log("Setting value for property: #{prop} - #{val}")
          RlmUtilities.rlm_set_q_property_value(SS_integration_dns, SS_integration_username, SS_integration_password, package_id, "#{prop_type} property add", prop, val.to_s)
        end
      end
    end
    @request_params.each_pair do |prop,val|
      prefixes.each do |prefix|
        if prop.start_with?(prefix) && !val.nil? && val.length > 0
        prop_mod = prop.gsub("#{component}_","")
          @auto.log("Request Params - Setting value for property: #{prop_mod} - #{val}")
          RlmUtilities.rlm_set_q_property_value(SS_integration_dns, SS_integration_username, SS_integration_password, package_id, "#{prop_type} property add", prop_mod, val.to_s)
        end
      end
    end
    RLM_BASE_PROPERTIES.each do |k|
        prop_name = "RPM_" + k.gsub("SS_", "").upcase
        prop_name = "RPM_VERSION" if prop_name == "RPM_COMPONENT_VERSION"
        val = @params[k]
        if  !val.nil? && val.length > 0
          @auto.log("Setting value for property: #{prop_name} - #{val}")
          RlmUtilities.rlm_set_q_property_value(SS_integration_dns, SS_integration_username, SS_integration_password, package_id, "#{prop_type} property add", prop_name, val)    
      end
    end
  rescue Exception => e
    return "Command_Failed: cannot set properties = #{e.message}"
  end
  return "Success"
end

def rpd_create_package_instance(package_id_or_name, wait_till_created = true, locked = "No", instance_name = nil)
  ########################Create package instance#################################################
  if package_id_or_name.is_a?(String)
    package_id = rpd_get_package_id(package_id_or_name)
    if package_id.to_i < 0
      @auto.log "Command_Failed: Package name not found"
      exit(1)
    end
  else
    package_id = package_id_or_name
  end   
  package_instance_response = RlmUtilities.create_package_instance(SS_integration_dns, SS_integration_username, SS_integration_password, package_id, locked, instance_name)
  package_instance_id = package_instance_response[0]["id"] rescue nil
  if package_instance_id.nil?
    @auto.log("Command_Failed: package instance creation failed.")
    exit(1)
    #raise "Error while creating the package instance."   
  else
    #pack_response "Package Instance", "#{package_instance_response[0]["value"].split(" ")[5]}:#{package_instance_response[0]["value"].split(" ")[2]}" rescue nil
    @auto.log("package instance processing...")
  end

  ######################## Check the status of package instance created ############################### 
  package_instance_status = "Waiting"
  if wait_till_created
    sleep_cnt = 0 # This delay is required as after creating the instance, status may not immedietly go to constructing
    begin
      delay_sleep(sleep_cnt)
      package_instance_status = RlmUtilities.get_package_instance_status(SS_integration_dns, SS_integration_username, SS_integration_password, package_instance_id)
      sleep_cnt += 1    
    end while (package_instance_status != "Ready" && package_instance_status != "Error")

    if package_instance_status == "Error" || package_instance_status != "Ready"
      @auto.log "Command_Failed: There were some problem while creating the package instance."
    else
      @auto.log("package instance is now in Ready state.")
    end
  else
    @auto.log "Working asynchronously - instance creation may still be happening"
  end
  {"status" => package_instance_status, "package_instance_id" => package_instance_id, "package_id" => package_id, "package_instance_response" => package_instance_response}
end

def rpd_deploy_package_instance(package_instance_id, deploy_route, target_env_id)
  ######################## Instance Deployment stage begins ############################### 
  deployment_instance_id = RlmUtilities.deploy_package_instance(SS_integration_dns, SS_integration_username, SS_integration_password, package_instance_id, deploy_route, target_env_id)
  if deployment_instance_id.nil?
    @auto.log("Command_Failed: Cannot deploy instance.")
    #raise "Error while deploying the package instance."  
    exit(1) 
  else
    @auto.log("package instance deployment is now started.")
  end

  ######################## Check the status of deployment ############################### 
  sleep_cnt = 0 # This delay is required as after creating the instance, status may not immedietly go to constructing
  begin
    delay_sleep(sleep_cnt)
    deploy_status = RlmUtilities.get_deploy_status(SS_integration_dns, SS_integration_username, SS_integration_password, deployment_instance_id)
    sleep_cnt += 1    
  end while (deploy_status != "pass" && deploy_status != "fail" && deploy_status != "cancelled")
  
  if deploy_status == "fail" ||  deploy_status == "cancelled" || deploy_status != "pass"
    @auto.log "Command_Failed: There were some problem while deploying the package instance."
  else
    @auto.log("package instance deployed successfully.")
  end
  {"status" => deploy_status, "deployment_instance_id" => deployment_instance_id}
end


def rpd_execute_api(command, args = [], options = {})
  url = "#{SS_integration_dns}/index.php/api/processRequest.xml"
  request_doc_xml = Builder::XmlMarkup.new
  request_doc_xml.q(:auth => "#{SS_integration_username} #{SS_integration_password}") do
    request_doc_xml.request(:command => "#{command}") do
      args.each do |arg|
        request_doc_xml.arg arg
      end
    end
  end 
  xml_response = RestClient.post url, request_doc_xml, :content_type => :xml, :accept => :xml
  xml_to_hash_response = XmlSimple.xml_in(xml_response)
  if xml_to_hash_response["result"][0]["rc"] != "0" || xml_to_hash_response["result"][0]["message"] != "Ok"
    raise "Error while posting to URL #{url}: #{xml_to_hash_response["result"][0]["message"]}"
  else
    hash_response = xml_to_hash_response["result"][0]["response"] 
    hash_response = hash_response.first.empty? ? nil : hash_response        
  end
  hash_response = xml_response if options.has_key?("raw_output")   
  return hash_response
end

def get_rpd_next_environment(args)
  command = "route next environment list"
  rest_result = rpd_execute_api(command,args)
  #log_it("Next Environment: #{rest_result.inspect}")
  result = {}
  stype = "open"
  rest_result.each do |item|
    if item.is_a?(String)
      if item == "Current Environment(s):"
        stype = "current"
      elsif item == "Next Environment(s):"
        stype = "promote"
      end
    else
      result["[#{item["id"]}]#{item["value"]}"] = stype
    end
  end
  result
end

def rpm_from_rpd_env(env)
  env[-8..-1].split("-")[1]
end

def global_timestamp
  if true #@p.timestamp == ""
    @timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    @request_params["timestamp"] = @timestamp
  else
    @timestamp = @p.timestamp
  end
  @timestamp
end 

