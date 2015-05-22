#  f2_rsc_baaGlobalPropertyDisctionaryBrowse.rb
#  Resource automation to present a tree control for file browsing via local

#=== BMC Application Automation Integration Server: EC2 BSA Appserver ===#
# [integration_id=5]
SS_integration_dns = "https://ip-172-31-36-115.ec2.internal:9843"
SS_integration_username = "BLAdmin"
SS_integration_password = "-private-"
SS_integration_details = "role : BLAdmins
authentication_mode : SRP"
SS_integration_password_enc = "__SS__Cj09d1lwZDJic1ZHWmh4bVk="
#=== End ===#

@role = "BLAdmins"

#---------------------- Declarations ------------------------------#
@script_name_handle = "library_tree"
#FRAMEWORK_DIR = "C:/BMC/persist/automation_libs"
FRAMEWORK_DIR = "/opt/bmc/resources/persist/automation_lib"
conts = File.open("#{FRAMEWORK_DIR}/brpm_framework.rb").read
eval conts

#---------------------- Methods ------------------------------#
def bl_auth
  "?username=#{SS_integration_username}&password=#{decrypt_string_with_prefix(SS_integration_password_enc)}&role=#{@role}"
end

def global_property_classes(frag = "", show_children = true)
  frag.chomp!("/")
  frag += "/" if show_children
  url = "#{SS_integration_dns}/type/PropertySetClasses/SystemObject#{frag}#{bl_auth}"
  result = rest_call(URI.escape(url), "get")
  result["data"]
end  
  
def child_groups(hsh)
  has_children = hsh["PropertySetClassChildrenResponse"]["PropertySetClassChildren"]["PropertySetClasses"]["totalCount"].to_i > 0
  child_classes = hsh["PropertySetClassChildrenResponse"]["PropertySetClassChildren"]["PropertySetClasses"]["Elements"]
end

#---------------------- Main Script ------------------------------#
def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  begin
    baa_url = SS_integration_dns
    
  #pout = []
  #script_params.each{|k,v| pout << "#{k} => #{v}" }
  #log_it "Current Params:\n#{pout.sort.join("\n") }"
    if parent_id.blank?
      # root folder
      log_it "Setting root: /SystemObject"
      data = []
      result = global_property_classes
      child_groups(result).each do |group|
        data << { :title => group["name"], :key => "#{group["name"]}|/", :isFolder => true, :hasChild => true}
      end
      return data
    else
      # clicked_item|/opt/bmc/stuff
      log_it "Drilling in: #{parent_id}"
      dir = File.join(parent_id.split("|")[1],parent_id.split("|")[0])
      dir = "/#{dir}" if parent_id.split("|")[1] == "//"
      result = global_property_classes(dir)
      groups = child_groups(result)
      return [] if groups.size == 0
      data = []
      groups.each do |group|
        is_folder = true
        data << { :title => group["name"], :key => "#{group["name"]}|#{dir}", :isFolder => is_folder, :hasChild => is_folder}
      end
      log_it(data)
      data
    end
  rescue Exception => e
    log_it "#{e.message}\n#{e.backtrace}"
  end
end

def import_script_parameters
  { "render_as" => "Tree" }
end

