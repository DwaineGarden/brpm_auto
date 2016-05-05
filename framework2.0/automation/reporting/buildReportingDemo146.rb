require 'json'
require 'yaml'
require 'rest-client'
require 'uri'

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
  verbose = get_option(options, "verbose") == "yes" || get_option(options, "verbose") == true
  headers = get_option(options, "headers", {:accept => :json, :content_type => :json})
  return result["message"] = "ERROR - #{method} not recognized" unless methods.include?(method)
  puts "Rest URL: #{url}" if verbose
  begin
    data = get_option(options, "data")
    rest_params = {}
    rest_params[:url] = URI.escape(url)
    rest_params[:method] = method.to_sym
    rest_params[:verify_ssl] = OpenSSL::SSL::VERIFY_NONE if url.start_with?("https")
    rest_params[:payload] = data.to_json unless data == ""
    if options.has_key?("username") && options.has_key?("password")
      rest_params[:user] = options["username"]
      rest_params[:password] = options["password"]
    end
    rest_params[:headers] = headers
    puts "RestParams: #{rest_params.inspect}" if verbose
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
  puts "Rest Response:\n#{response.inspect}" if verbose
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

def set_scheduled_request(request_id, schedule_time)
  puts "Updating schedule for request to next window\nWindow: #{schedule_time}"
  req = {"request" => {"scheduled_at" => schedule_time, "auto_start" => true, "aasm_event" => "plan_it"}}
  res = rest_call("#{@base_url}/v1/requests/#{request_id}?token=#{@token}", "PUT", {"verbose" => "yes", "data" => req})
  puts("ERROR - cannot set schedule") if res["status"] == "ERROR"
  res
end

def set_version_tags(tag, component, environment, request_info)
  tag_url = "#{@base_url}/v1/version_tags?token=#{@token}&filters[name]=#{tag}"
  tags = rest_call(tag_url, "GET")
  tag_id = 0
  tags["data"].each do |version|
    if version["component_name"] == component && version["environment_name"] == environment
      tag_id = version["id"]
    end
  end
  request_info["steps"].each do |step|
    #find component
    if step["component_name"] == component
      puts "Found step - update with version: #{tag_id}"
      step_data = {"step" => {"version_tag_id" => tag_id}}
      step_url = "#{@base_url}/v1/steps/#{step["id"]}?token=#{@token}&filters[name]=#{tag}"
      result = rest_call(step_url, "PUT", {"data" => step_data, "verbose" => true})
    end
  end
  
end

def create_version_tags(seed_data)
  tags = {}
  seed_data.each do |app,details|
    puts "#{app} - Adding Versions"
    details["versions"].each do |ver|
      details["components"].each do |comp|
        puts "v.#{ver} for #{comp}"
        tag_url = "#{@base_url}/v1/version_tags?token=#{@token}&filters[name]=#{ver}&filters[component_name]=#{comp}"
        tags = rest_call(tag_url, "GET", {"suppress_errors" => true})
        if tags["status"] == "success"
          puts "Tag Found"
          next
        end
        version_attrs = {"name" => ver, "find_application" => app, "find_component" => comp, "artifact_url" => "http://vw-aus-rem-dv11.bmc.com:8080/job/#{app}_main_trunk/356/artifact/#{app}_201505220925.zip"}
        res = rest_call("#{@base_url}/v1/version_tags?token=#{@token}", "POST", {"verbose" => "yes", "data" => {"version_tag" => version_attrs}})
        tags[ver] = {comp => res["id"]}
      end
    end
  end
  tags
end

#GCAS, CXF and Elvis
#Plan - Utility Feeds
#Versions:
#Elvis:  4.5.08 - .09, .10 - ELVIS_Deployment_Request - ALM, WebServer, AppServer
#GCAS:   3.3.00 - .01, .02, .03 - GCAS Deploy - GCAS Feeds, GCAS Web
#CXF:    2.15.4 - .5b, .5 - CXF Deploy - Release_Logic, AppServer


@base_url = "http://ec2-54-208-221-146.compute-1.amazonaws.com:4005/brpm"
@token = "a56d64cbcffcce91d306670489fa4cf51b53316c"
@plan_info = {30 => {"DEV" => 27, "SIT" => 28, "UAT" => 28, "PROD" => 29}}
environments = %w(DEV SIT UAT)
coordinator_id = 3
start_time = 2
seed_data = {
  "Elvis" => {"template" => "ELVIS_Deployment_Request", "components" => ["ALM", "WebServer", "AppServer"], "versions" => ["4.5.11", "4.5.12", "4.5.13"]}, 
  "GCAS" => {"template" => "1.0_GCAS Deploy", "components" => ["GCAS Feeds", "GCAS Web"], "versions" => ["3.3.03", "3.3.04", "3.3.05"]}, 
  "CXF" => {"template" => "1.0_CXF Deploy", "components" => ["Release_Logic", "AppServer"], "versions" => ["2.15.6", "2.15.7b", "2.15.7"]}
}
plan_id = @plan_info.keys[0]

v_tags = create_version_tags(seed_data)
environments.each_with_index do |env, env_idx|
  seed_data.each do |app, details|
    puts "Updating App: #{app}"
    request_attrs = {"request" => {"template_name" => details["template"], "environment" => env, "deployment_coordinator_id" => coordinator_id, "requestor_id" => coordinator_id}}
    request_attrs["request"]["plan_member_attributes"] = {"plan_id" => plan_id, "plan_stage_id" => @plan_info[plan_id][env]}
    url = "#{@base_url}/v1/requests?token=#{@token}"
    next if 
    details["versions"].each_with_index do |version, ver_idx|
      next if env_idx == 1 && ver_idx == 2
      next if env_idx == 2 && (ver_idx == 2 || ver_idx == 1)
      result = rest_call(url, "POST", {"verbose" => "yes", "data" => request_attrs})
      request_id = result["data"]["id"]
      details["components"].each do |comp|
        puts "Updating Steps: #{version} - #{comp}, #{env}, #{result["data"]["steps"][1].inspect}"
        set_version_tags(version, comp, env, result["data"])  #update steps with versions
      end
      schedule_time = (Time.now + (start_time * 60))
      set_scheduled_request(request_id, schedule_time)
    end
  end
end