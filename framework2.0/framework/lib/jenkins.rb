require 'uri'
require 'net/http'

# Base class for working with Subversion
class Jenkins < BrpmAutomation
  
  # Initializes an instance of the class
  #
  # ==== Attributes
  #
  # * +url+ - url for Jenkins server...
  # * +params+ - params hash
  # * +options+ - hash of options includes:...
  #   job_name - jenkins job name (from url)...
  #   username - jenkins user username...
  #   password - jenkins user password...
  #   verbose - true for verbose output (default = false)...
  #   simulate - simulate command - echo it (default = false)...
  #
  def initialize(url, params, options)
    @url = url
    @username = get_option(options,"username")
    @password = get_option(options,"password")
    @job_name = get_option(options,"job_name")
    @verbose = get_option(options,"verbose", false)
    @simulate = get_option(options,"simulate", false)
    super(params)
  end
  
  # Calls the jenkins server via rest
  # Uses the current project and auth information
  # ==== Attributes
  # * +options+ - a hash of options, includes:
  #  url_part - the fragment of the url past the project ex.
  #  for this url: http://vw-aus-rem-dv11.bmc.com:8080/job/BRPM_4.6-D_WAR/231/api/json
  #  the fragment is "231/api/json"
  #  username - override existing username
  #  password - override existing password
  #  method - get/post, defaults to get
  #
  # ==== Returns
  #
  # * +rest_result+ - hash of information including status (success-failure) and data - the rest result 
  #
  def jenkins_rest_call(url_part, options = {})
    result = {"status" => "Failure"}
    options["username"] = @username unless options.has_key?("username")
    options["password"] = @password unless options.has_key?("password")
    method = get_option(options,"method") == "post" ? "post" : "get"
    url = File.join(@url,"job",@job_name, url_part)
    log "Full url [#{method}]: #{url}" if @simulate || @verbose      
    unless @simulate
      response = rest_call(url, method, options) 
      log "Response: #{response.inspect}" if @verbose
      result["data"] = "#{response["status"]}: #{response["message"]}" unless response["status"] == "success"
      result["data"] = response["data"] if response["status"] == "success"
      result["status"] = response["status"]
    else
      result["status"] = "simulate"
    end
    result
  end
  
  def set_job_name(new_name)
    @job_name = new_name
    new_name
  end
  
  # Returns the array of Build Jobs
  #
  # ==== Returns
  #
  # * +job_list+ - an array of hashes with job information
  #
  def job_list
    options = {"username" => @username, "password" => @password}
    response = rest_call("#{@url}/api/json", "get", options)
    return "ERROR" if response["status"] == "ERROR"
    response["data"]
  end

  # Returns the data of a Build Job
  #
  # ==== Returns
  #
  # * +job_data+ - a hash of job information
  #
  def job_data
    jenkins_rest_call("/api/json")
  end

  # Returns the data of a build
  # ==== Attributes
  #
  # * +build_no+ - the id of a build (omit for latest build)
  #
  # ==== Returns
  #
  # * +job_data+ - a hash of job information
  #
  def job_build_data(build_no = nil)
    build_no = "lastBuild" if build_no.nil?
    jenkins_rest_call("#{build_no}/api/json")
  end

  # Returns the status of a build
  # ==== Attributes
  #
  # * +build_no+ - the id of a build (omit for latest build)
  #
  # ==== Returns
  #
  # * +hash+ - still_building (ture/false) and status (success/fail)
  #
  def build_status(build_no = nil)
    response = job_build_data(build_no)
    # Now parse for the status and build id
    #log "Raw Result: #{response.inspect}"
    ans = {}
    ans["still_building"] = response["data"]["building"]
    ans["success"] = response["status"]
    ans
  end

  # Returns the raw results of a build
  # ==== Attributes
  #
  # * +build_no+ - the id of a build (omit for latest build)
  # * +get_link+ - returns a link to the results instead (optional - default = false)
  #
  # ==== Returns
  #
  # * +job_data+ - text of build output
  #
  def build_results(build_no, get_link = false)
    url_part = "#{build_no}/consoleText"
    if get_link
      response = File.join(@url,"job",@job_name, url_part)
    else
      response = jenkins_rest_call(url_part, {"headers" => {}})
    end
    response
  end

  # Monitors a running build
  # ==== Attributes
  #
  # * +build_no+ - the id of a build (omit for latest build)
  #
  # ==== Returns
  #
  # * +job_data+ - a hash of job information
  #
  def monitor_build(build_no)
    # start with an initial build result
    # Now parse for the status and build id
    max_time = MaxBuildTime
    sleep_interval = 15
    result = build_status(build_no)
    results = "Initial test: Build Number: #{build_no}, Status - building: #{result["still_building"].to_s}, result: #{result["success"]}\n"
    # Now Check to see if the token matches
    build_match = true
    #build_match = response.include?(ss_token) if use_token_match # Enable this if using token matching
    message_box "Monitoring Build Progress (id: #{build_no})"
    if build_no.to_i > 0 && result["still_building"] == true && build_match
      start_time = Time.now
      elapsed = 0
      complete = false
      until elapsed > (max_time * 60) do
        result = build_status(build_no)
        results += "Status - building: #{result["still_building"].to_s}, result: #{result["success"]}\n"
        if result["still_building"] == false
          log "Success - #{result["success"]}"
          complete = true if result["success"] == "SUCCESS"
          complete = false if result["success"] != "SUCCESS"
          break
        else
          elapsed = Time.now - start_time
          log "Still building ...elapsed: #{elapsed.to_i.to_s}, pausing for #{sleep_interval.to_s} seconds"
          sleep sleep_interval
        end
        elapsed = Time.now - start_time
      end
    elsif  result["success"] != "SUCCESS"
      log "Build failed on initial parameters, either could not retrieve build id or token did not match output"
      complete = false
    else
      log "Build Successful"
      complete = true
    end
    complete
  end

  # Performs a build on the active project
  # ==== Attributes
  #
  # * +build_arguments+ - a hash of the build arguments
  #
  # ==== Returns
  #
  # * +job_data+ - a hash of job information
  #
  def build(build_arguments = {})
    # Fetch the next build number
    build_details = job_data
    next_build = build_details["data"]["nextBuildNumber"]
    url_part = "build"
    options = {"method" => post, "data" => build_arguments}
    reponse = jenkins_rest_call(url_part, options)
    last_build = next_build  
    result = "Web server response: " + response["header"]
    log result
    unless response["header"].include?("HTTPFound 302") #response["status"] == "failure"
      log "Command_Failed: Build did not launch"
      return -1
    end
    launched = false
    10.times do 
      test_result = job_build_data(last_build)
      if test_result["data"].is_a?(String) && test_result["data"].include?("failure")
        log "Job not ready waiting..."
        sleep(6)
      else
        launched = true
        break
      end
    end
    if launched
      return last_build
    else
      log "Command_Failed: Build did not launch in 60 seconds"
      return -1
    end
  end
  
  
  # Returns the status of a build
  # ==== Attributes
  #
  # * +build_no+ - jenkins build id
  # * +artifact_name+ - name from the build artifacts list in job data
  # * +target_path+ - folder to download to (default is SS_output_dir)
  #
  # ==== Returns
  #
  # * +status+ - success or failure
  #
  def get_build_artifact(build_no, artifact_name, target_path = nil)
    # http://vw-aus-rem-dv11.bmc.com:8080/job/BRPM_4.6-D_WAR/lastSuccessfulBuild/artifact/brpm_231.war
    url_part = "#{build_no}/artifact/#{artifact_name}"
    url = File.join(@url,"job",@job_name, url_part)
    target_path = @params["SS_output_dir"] if target_path.nil?
    fetch_artifact(url, target_path)
  end
  
  private
  
  def download_file(artifact_url, download_path)
    package_name = artifact_url.split("/").last
    uri = URI(artifact_url)  
    Dir.chdir(download_path)
    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Get.new uri.request_uri
      log "Downloading: #{artifact_url} to #{download_path}"
      fil = open(package_name, "wb")
      begin
        http.request_get(uri.request_uri) do |resp|
          resp.read_body do |segment|
            fil.write(segment)
          end
        end
      ensure
        fil.close()
      end
    end
    "Downloaded to: #{download_path}"
  end
  
  def fetch_artifact(url, download_path)
    _response = Net::HTTP.get_response( URI.parse( url ) )
    package_name = url.split("/").last
    case _response
    when Net::HTTPSuccess then
      response = download_file(url, download_path)
      _response
    when Net::HTTPRedirection then
      location = _response['location']
      log "\tRedirected to #{location}"
      response = download_file(location, download_path)
      _response
    else
      _response.value
    end
  end
    
end
