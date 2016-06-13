#---------------------- f2_restCall -----------------------#
# Description: makes a web services call

#---------------------- Arguments --------------------------#
###
# URL:
#   name: URL to query
#   position: A1:F1
#   type: in-text
# REST_Method:
#   name: http method
#   type: in-list-single
#   list_pairs: get,get|put,put|post,post|delete,delete
#   position: A2:C2
# REST_Data:
#   name: JSON data to send (for post or put) 
#   position: A3:F3
#   type: in-text
# REST_Headers:
#   name: header info if necessary
#   position: A4:F4
#   type: in-text
# REST_Username:
#   name: username if required (basic auth)
#   position: A5:C5
#   type: in-text
# REST_Password:
#   name: password if required (basic auth)
#   position: D5:F5
#   private: yes
#   type: in-text
# Success_Phrase:
#   name: test to find in response
#   position: A6:F6
#   type: in-text
# Verbose:
#   name: test to find in response
#   position: A7:B7
#   type: in-list-single
#   list_pairs: no,no|yes,yes
###

<%

def log_item(txt)
  File.open(@log_file, "a") do |fil|
   fil.puts txt
   fil.flush
  end
end

begin
  require "#{@framework_dir}/lib/rest"
  Token = "9f45b735ac2c7616f875007e7f61409c290b4285"
  @rest = BrpmRest.new(@p.SS_base_url, @p.params)
  @log_file = "/tmp/pipeline_log.txt"

#---------------------- Variables --------------------------#
  url = @p.get("URL")
  method = @p.required("REST_Method")
  rest_data = @p.get("REST_Data")
  headers = @p.get("REST_Headers")
  username = @p.get("REST_Username")
  password = @p.get("REST_Password")
  success = @p.get("Success_Phrase")
  verbose = @p.get("Verbose")
  rest_options = {}
  has_error = false
  output_message = "DefaultOutput"
  
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
  log_item "Running rest call: #{url}"
  result = @rpm.rest_call(url, method, rest_options)
  log_item "Rest Result\n#{result.inspect}"

# Apply success or failure criteria
  if result["status"] == "success" && result["data"].inspect.include?(success)
    @rpm.log "Success - found term: #{success}\n"
    output_message = "echo Rest Result"
    result["data"].inspect.each_line{|k| output_message += "echo #{k}" }
  else
    output_message = "echo Command_Failed\n"
result["message"].inspect.each_line{|k| output_message += "echo #{k}" }
    @rpm.log "Command_Failed - term not found: [#{success}]\n"
  end
rescue => e
  has_error = true
  output_message += e.message
  e.backtrace.each_line{|k| output_message += "echo #{k}" }
  @rpm.log error_msg
end
%>
<%= "echo Running Pipeline Rest Call\necho URL: #{url}" %>
<%= output_message %>
