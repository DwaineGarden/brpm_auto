#---------------------- f2_util_importUsersandGroups -----------------------#
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
# csv_upload_file:
#   name: File 1
#   type: in-file
#   position: A1:F1
###

#---------------------- Declarations -----------------------#
require 'csv'
params["direct_execute"] = true

#---------------------- Methods ----------------------------#

def user_exists(login, return_result = false)
  result = true
  ans = @rest.get("users",nil,{"filters" => "filters[keyword]=#{login}", "suppress_errors" => true})
  result = false if ans.has_key?("message") && ans["message"].start_with?("404")
  return_result ? ans : result
end

def group_exists(group_name, return_result = false)
  result = true
  ans = @rest.get("groups",nil,{"filters" => "filters[name]=#{group_name}", "suppress_errors" => true})
  result = false if ans.has_key?("message") && ans["message"].start_with?("404")
  return_result ? ans : result
end

def get_user_id(login)
  uid = -1
  @new_users.each_with_index{|l, idx| uid = l[1] if l[0] == login }
  if uid < 0
    result = user_exists(login, true)
    return uid if result.has_key?("message") && result["message"].start_with?("404")
    uid = result["data"][0]["id"]
  end
  uid
end
      
#---------------------- Variables --------------------------#
source_file = @p.get("csv_upload_file")

#---------------------- Main Body --------------------------#

raise "ERROR - can not locate csv file" if source_file == ""

@rpm.message_box "Importing Users/Groups from: #{source_file}", "title"
conts = File.open(source_file).read
csv = CSV.parse(conts, :headers => true)
@new_users = []

@rpm.log "#===========  Creating Users =============#"
csv.each do |row|
  row_data = row.to_hash
  if row_data["Type"] == "User"
    user_data = {"login" => row_data["name"], 
      "first_name" => row_data["first_name"], 
      "last_name" => row_data["last_name"], 
      "email" => row_data["email"],
      "password" => "bmc123", "roles" => ["requestor"]}
    exists = user_exists(row_data["name"])
    if exists
      @rpm.log "User: #{row_data["name"]} exists, skipping"
      next
    else
      @rpm.log "User: #{row_data["name"]} being created"
    end
    result = @rest.create("users", user_data)
  
    if result["status"] != "success"
      @rpm.log "user creation failed: #{user_data}"
    else
      @new_users << [ user_data["login"], result["data"]["id"] ]
    end
  end
end

@rpm.log "#===========  Creating Groups =============#"
csv.each do |row|
  row_data = row.to_hash
  if row_data["Type"] == "Group"
    group_data = {"name" => row_data["name"] 
    }
    group_data["email"] = row_data["email"] if !row_data["email"].nil? && row_data["email"].include?("@")
    exists = group_exists(row_data["name"])
    if exists
      @rpm.log "Group: #{row_data["name"]} exists, skipping"
      next
    else
      @rpm.log "Group: #{row_data["name"]} being created"
    end
    result = @rest.create("groups", group_data)
  
    if result["status"] != "success"
      @rpm.log "group creation failed: #{group_data}"
    end
    if row_data["members"].length > 2
      members = row_data["members"].split(" ")
      uids = []
      members.each do |usr|
        @rpm.log "\tMember: #{usr}"
        uid = get_user_id(usr)
        uids << uid if uid > 0
      end
      g_data = {"resource_ids" => uids}
      result = @rest.update("groups", result["data"]["id"], g_data)
    end
  end
end

