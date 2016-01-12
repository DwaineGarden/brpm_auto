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
#---------------------- Variables --------------------------#
url = @p.get("URL")
method = @p.required("REST Method")
rest_data = @p.get("REST Data")
headers = @p.get("REST Headers")
username = @p.get("REST Username")
password = @p.get("REST Password")
success = @p.get("Success Phrase")
verbose = @p.get("Verbose")
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
result = @rpm.rest_call(url, method, rest_options)


# Apply success or failure criteria
if result["status"] == "success" && result["data"].inspect.include?(success)
  @rpm.log "Success - found term: #{success}\n"
else
  @rpm.log "Command_Failed - term not found: [#{success}]\n"
end
