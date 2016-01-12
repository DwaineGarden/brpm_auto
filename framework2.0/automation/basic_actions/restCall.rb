#---------------------- f2_restCall -----------------------#
# Description: makes a web services call

#---------------------- Arguments --------------------------#
###
# URL:
#   name: URL to query
#   position: A1:F1
#   type: in-text
# REST Method:
#   name: http method
#   type: in-list-single
#   list_pairs: get,get|put,put|post,post|delete,delete
#   position: A2:C2
# REST Data:
#   name: JSON data to send (for post or put) 
#   position: A3:F3
#   type: in-text
# REST Headers:
#   name: header info if necessary
#   position: A4:F4
#   type: in-text
# REST Username:
#   name: username if required (basic auth)
#   position: A5:C5
#   type: in-text
# REST Password:
#   name: password if required (basic auth)
#   position: D5:F5
#   private: yes
#   type: in-text
# Success Phrase:
#   name: test to find in response
#   position: A6:F6
#   type: in-text
# Verbose:
#   name: test to find in response
#   position: A7:B7
#   type: in-list-single
#   list_pairs: no,no|yes,yes
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution

#---------------------- Method --------------------------#
# 
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
  verbose = get_option("verbose","", options) == "yes" || get_option("verbose","", options)
  headers = get_option("headers", {:accept => :json, :content_type => :json}, options)
  return result["message"] = "ERROR - #{method} not recognized" unless methods.include?(method)
  write_to "Rest URL: #{url}" if verbose
  begin
    data = get_option("data","", options)
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
    write_to "RestParams: #{rest_params.inspect}" if verbose
    if %{put post}.include?(method)
      return result["message"] = "ERROR - no data param for post" if data == ""
      response = RestClient::Request.new(rest_params).execute
    else
      response = RestClient::Request.new(rest_params).execute
    end
  rescue Exception => e
    result["message"] = e.message
    raise "RestError: #{result["message"]}" unless get_option("suppress_errors","", options) == true
    return result
  end
  write_to "Rest Response:\n#{response.inspect}" if verbose
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
    raise "RestError: #{result["message"]}" unless get_option("suppress_errors","", options) == true
  end
  result
end

# Provides a simple failsafe for working with hash options
# returns "" if the option doesn't exist or is blank
# ==== Attributes
#
# * +key+ - key to find in options
# * +default_value+ - if entered will be returned if the option doesn't exist or is blank
# * +options+ - the hash defaults to params
def get_option(key, default_value = "", options = @params)
  result = options.has_key?(key) ? options[key] : nil
  result = default_value if result.nil? || result == ""
  result 
end

def required_option(key, options = @params)
  raise "Command_Failed: #{key} is required" if get_option(options, key) == ""
  get_option(key, "", options)
end

#---------------------- Variables --------------------------#
url = required_option("URL")
method = required_option("REST Method")
rest_data = get_option("REST Data")
headers = get_option("REST Headers")
username = get_option("REST Username")
password = get_option("REST Password")
success = get_option("Success Phrase")
verbose = get_option("Verbose")
rest_options = {}
#---------------------- Main Body --------------------------#
# 
if ["put", "post"].include?(method)
  raise "Command_Failed: must have data param for put and post methods" if rest_data == ""
  rest_options["data"] = JSON.parse(rest_data)
end
rest_options["verbose"] = verbose
rest_options["headers"] = headers unless headers == ""
unless password == ""
  rest_options["password"] = password
  rest_options["username"] = username
end
result = rest_call(url, method, rest_options)




# Apply success or failure criteria
if result["status"] == "success" && result["data"].inspect.include?(success)
  write_to "Success - found term: #{success}\n"
else
  write_to "Command_Failed - term not found: [#{success}]\n"
end
