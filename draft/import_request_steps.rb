#---------------------- f2_util_importSteps -----------------------#
# Description: Imports users and gropus from a csv file
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
# Users and Groups import from csv.  Pass a csv file
# Headers should be in the first row.
# Header names:
#  Type, first_name, last_name, email, name, members
# Where: Type is 'User' or 'Group', name is the login or group name
# members is space separated logins to be added to the group
#  All added users will get a new password of 'bmc123'

#---------------------- Arguments --------------------------#
###
# upload_tab_text_file:
#   name: File 1
#   type: in-file
#   position: A1:F1
###

#---------------------- Declarations -----------------------#
require 'iconv'
require 'uri'
params["direct_execute"] = true

#---------------------- Methods ----------------------------#

def installed_component_exists(comp_name, return_result = false)
  result = true
  ans = @rest.get("installed_components",nil,{"filters" => "filters[app_name]=#{URI.encode(@p.SS_application)}&filters[environment_name]=#{URI.encode(@p.SS_environment)}&filters[component_name]=#{URI.encode(comp_name)}", "suppress_errors" => true})
  result = false if ans.has_key?("message") && ans["message"].start_with?("404")
  return_result ? ans : result
end

def group_exists(name, return_result = false)
  result = true
  ans = @rest.get("groups",nil,{"filters" => "filters[name]=#{URI.encode(name.gsub(/\'/,"''"))}", "suppress_errors" => true})
  result = false if ans.has_key?("message") && ans["message"].start_with?("404")
  return_result ? ans : result
end

def user_exists(name, return_result = false)
  result = true
  ans = @rest.get("users",nil,{"filters" => "filters[keyword]=#{URI.encode(name.gsub(/\'/,"''"))}", "suppress_errors" => true})
  result = false if ans.has_key?("message") && ans["message"].start_with?("404")
  return_result ? ans : result
end

def get_installed_component(comp_name)
  res = nil
  @components.each_with_index{|l, idx| res = l if l[0] == comp_name }
  if res.nil?
    result = installed_component_exists(comp_name, true)
    return res if result.has_key?("message") && result["message"].start_with?("404")
    res = [comp_name, result["data"][0]["id"], result["data"][0]["application_component"]["component"]["id"]]
    @components << res
  end
  res
end

def get_user_group(name)
  res = nil
  @assignees.each_with_index{|l, idx| res = l if l[0] == name }
  if res.nil?
    result = group_exists(name, true)
    if result.has_key?("message") && result["message"].start_with?("404")
      result = user_exists(name, true)
      if result.has_key?("message") && result["message"].start_with?("404")
        return(res)
      else
        res = [name, result["data"][0]["id"], "User"]
        @assignees << res
      end
    else
      res = [name, result["data"][0]["id"], "Group"]
      @assignees << res
    end
  end
  res
end
     
#---------------------- Variables --------------------------#
source_file = @p.get("upload_tab_text_file")
request_id = @p.request_id.to_i - 1000

#---------------------- Main Body --------------------------#

raise "ERROR - can not locate tab-text file" if source_file == ""

@rpm.message_box "Importing Steps from: #{source_file}", "title"



cur_request = @rest.get("requests", request_id)
#template_step = cur_request["data"]["steps"][0][id]
@components = []
@assignees = []

conts = File.open(source_file).read
# Remove Excel gremlins
iconv = Iconv.new('UTF-8//IGNORE', 'UTF-8')
clean_data = iconv.iconv(conts)
clean_data = clean_data.gsub("\n", "_BREAK_").gsub("\r","\n")

@rpm.log "#===========  Creating Steps =============#"

rows = clean_data.split("\n")
@headers = rows[0].split("\t")
Start = @headers.index("Start")
Description = @headers.index("Description")
Assigned_to	= @headers.index("Assigned_to")
Status = @headers.index("Status")
Component	= @headers.index("Component")
Estimate = @headers.index("Estimate")
Name = @headers.index("Name")

rows[1..-1].each do |row|
  puts "#=> ROW: #{row.gsub("\t",", ")}"
  row_data = row.split("\t")
  installed_comp = get_installed_component(row_data[Component])
  if installed_comp.nil?
    @rpm.log "Component: #{row_data[Component]} - not found, skipping"
    next
  end
  installed_component_id = installed_comp[1]
  component_id = installed_comp[2]
  assignee = get_user_group(row_data[Assigned_to])
  owner_type = assignee[2]
  owner_id = assignee[1]
  step_data = {
    "request_id" => request_id,
    "name" => row_data[Name].gsub('"',"").gsub("_BREAK_"," "),
    "description" => row_data[Description].gsub("_BREAK_","\n").gsub('"',""),
    "owner_type" => owner_type,
    "owner_id" => owner_id,
    "component_id" => component_id,
    "estimate" => row_data[Estimate],
    "installed_component_id" => installed_component_id, 
    "start_by" => row_data[Start]
    }
  @rpm.log "Step: #{row_data[Name]} - creating"
  result = @rest.create("steps", step_data)

  if result["status"] != "success"
    @rpm.log "step creation failed: #{step_data}"
  end

end


