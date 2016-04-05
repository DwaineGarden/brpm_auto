#---------------------- Add Request to Lifecycle -----------------------#
#    Launches a request and then puts it in the plan and stage
#
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
#---------------------- Arguments ---------------------------#
###
# request_template:
#   name: Name of request template 
#   type: in-text
#   position: A1:D1
#   required: yes
# Promotion Environment:
#   name: Environment to promote to
#   type: in-external-single-select
#   position: A2:C2
#   external_resource: f2_rsc_promotionEnvironments
#   required: no
# promotion_stage:
#   name: Stage to promote to 
#   type: in-text
#   position: A3:D3
#   required: no
# auto_promote:
#   name: Environments where request needs to be started manually (set to off to disable)
#   type: in-text
#   position: A4:D4
#   required: no
# wait_till_complete:
#   name: Wait for request to complete (optional - yes/no - default=no)
#   type: in-list-single
#   list_pairs: yes,yes|no,no
#   position: A5:C5
###

#---------------------- Declarations -----------------------#

#---------------------- Variables -----------------------#
# Assign local variables to properties and script arguments
# BJB - take request param if available
calling_request = @p.get("calling_request", "none")
bypass_promotion = @p.get("bypass_promotion") == "yes" ? true : false
# BJB 9-20-12 To allow manual redeploy, always accept script arguments over the request_params if they exist
target_env_info = @p.get("promotion_environment")
target_env_info = @p.get("Promotion Environment") if @p.get("Promotion Environment") != ""
template_name = @p.get("promotion_request_template", @p.get("request_template"))
monitor_options = {"max_time" => 60} # Note you can pass other options like {"monitor_step_name" => "database init", "max_time" => 60}
wait_for_completion = (@p.wait_till_complete == "yes")
send_request_data = (@p.send_request_data == "yes")
plan_member_id = @p.request_plan_member_id.to_i
execute_now = false
target_env_name = nil; target_stage = nil
cur_env_name = @p.SS_environment
if plan_member_id > 0
  plan = @p.request_plan
  plan_id = @p.request_plan_id.to_i
  plan_stage = @p.request_plan_stage
end  
manual_environment = @p.auto_promote
bypass_promotion = true if manual_environment.downcase == "off"

#---------------------- Methods -----------------------#

def deployment_window(environment_id)
  cur_time = Time.now
  ans = @rest.get("deployment_window/series",nil,{"filters" => "filters[environment]=#{environment_id}", "suppress_errors" => true})
  unless ans["status"] == "ERROR" # No windows defined for env
    last_series_id = 0 #work around for defect
    window = nil
    ans["data"].each do |ser|
      next if last_series_id == ser["id"] || !ser["archived_at"].nil?
      series = @rest.get("deployment_window/series",ser["id"])
      series["data"]["events"].each do |event| 
        if Time.parse(event["start_at"]) > cur_time
          window = event
          window["series_id"] = ser["id"]
          window["name"] = ser["name"]
          break
        end
      end
      last_series_id = ser["id"]
    end
  end
  if window.nil?
    @rpm.log "NO AVAILABLE DeploymentWindow - not scheduling request"
    return nil
  end
  window
end

def set_scheduled_request(request_id, window)
  @rpm.log "Updating schedule for request to next window\nWindow: #{window["name"]} - #{window["start_at"]}"
  req = {"request" => {"scheduled_at" => window["start_at"], "auto_start" => true, "aasm_event" => "plan_it"}}
  res = @rest.update("requests",request_id, req)
  @rpm.message_box("ERROR - cannot set schedule") if res["status"] == "ERROR"
  res
end

def modify_steps(request, update_list)
  # get all the groups
  status_message = "Setting step owners: #{update_list}"
  groups = group_list
  update_list.each do |name,values|
    request["steps"].each do |step|
      next unless step["name"].downcase.start_with?(name.downcase)
      status_message += "\nFound step: #{step["name"]}"
      step_data = {}
      values.each do |value|
        if value.is_a?(Hash)
          value.each{ |k,v| step_data[k] = v }           
        elsif value.start_with?("lookup:")
          status_message += ", looking up group: #{value.gsub("lookup:","")}"
          owner = lookup_property(value.gsub("lookup:",""), @target_env)
          group_id = ""
          groups.each{|item| group_id = item["id"] if item["name"].downcase == owner.downcase }
          if group_id != ""
            status_message += ", found it: id=#{group_id}"
            step_data["owner_id"] = group_id
            step_data["owner_type"] = "Group"
          end
        elsif value.start_with?("automation:")
          script_id = value.gsub("automation:","")
          if script_id.length > 1
            step_data["script_id"] = script_id
            status_message += ", updating script to #{script_id}"
          end
        end
      end
      url = "#{BaseURL}/v1/steps/#{step["id"]}?token=#{Token}"
      rest_result = rest_call(url, "PUT", {"data" => step_data})
      if rest_result["status"] == "success"
        write_to "Updating step: #{url}\nResult: #{rest_result["response"]}"
        result = "success"
        status_message += ", Updated step #{step["id"]}"
      end
    end
  end
  status_message
end

def ensure_version_tags(new_request, target_env)
  current_request = @rest.get("requests", (@p.request_id.to_i - 1000))
  version_steps = current_request["data"]["steps"].select{|l| !l["component_version"].nil? && l["component_version"] != "" }
  version_tags = {}
  versions = version_steps.map{|l| "#{l["component_version"]}|#{l["component_name"]}" }.uniq 
  version_steps.each do |step|
    tag_name = step["component_version"]
    component = step["component_name"]
    new_step = nil
    new_request["data"]["steps"].each{|k| new_step = k if k["name"] == step["name"] && k["component_name"] == step["component_name"] }
    if new_step.nil?
      @rpm.log "Cannot find match for step|component: #{step["name"]}|#{component}"
      next
    end
    tag = nil
    if version_tags.keys.include?("#{tag_name}|#{component}")
      tag = version_tags["#{tag_name}|#{component}"]
    else
      @rest.version_tag_query(tag_name).each{|v| tag = v if v["environment_name"] == target_env && v["component_name"] == component }
      if tag.nil?
        @rpm.log "VersionTag: #{tag_name} not exposed in #{target_env}"
        next
      end
      version_tags["#{tag_name}|#{component}"] = tag
    end
    @rpm.log "Assigning Version: #{tag_name} to step[#{new_step["position"]}]: #{new_step["name"]}/#{component}"
    res = @rest.update("steps", new_step["id"], {"step" => {"version_tag_id" => tag["id"], "component_version" => tag_name}})
  end
end

#---------------------- Main Routine -----------------------#
#
if bypass_promotion
  @rpm.message_box "Skipping Promotion", "sep"
  @rpm.log " Promotion property (or bypass) set to false"
  exit 1
end
if target_env_info == "none" # Multiple promotions - this is the 2nd automated promotion
  raise "ERROR cannot promote - missing route data (app_route_options)" if @p.app_route_options == ""
  is_cur = false; env_parts = []
  @p.app_route_options.each do |rt_info|
    if is_cur
      if rt_info["environment_type"] != @p.request_environment_type
        env_parts << rt_info["environment_id"]
        env_parts << rt_info["environment"]
        env_parts << rt_info["stage"] if plan_member_id > 0
        break
      end
    end
    is_cur = true if rt_info["environment"] == cur_env_name
  end
  raise "ERROR cannot promote - cannot determine environment" if env_parts == []
else
  raise "ERROR - no promotion environment selected" unless target_env_info.include?("|")
  env_parts = target_env_info.split("|") 
end # Target specified, first promotion
target_env_name = env_parts[1] 
target_env_id = env_parts[0]
target_stage = env_parts[2] if env_parts.size == 3    
@p.assign_local_param("promotion_environment", "none") # this will flag for next promotion to be calculated
cur_name = @p.request_name.include?("Automated promotion") ? @p.request_name.gsub(/\s-\sAutomated\spromotion.*/,"") : @p.request_name
new_req_name = "#{cur_name} - Automated promotion to #{target_env_name} Stage: #{target_stage}"

if(target_env_id.nil? || target_env_id.length < 1 || template_name.length < 2)
  @rpm.message_box("Missing promotion environment or template name: Command_Failed", "title")
  exit(1)
end
@p.assign_local_param("calling_request", @p.get("SS_request_number"))
if !target_stage.nil?
  @rpm.message_box("Launching Promotion Request","title")
  @rpm.log "\tRequest Template: #{template_name}"
  @rpm.log "\tEnvironment: #{target_env_name}"
  target_stage = @p.get("promotion_stage") if target_stage == "none"
  if plan_member_id > 0
    @rpm.log "\tPlan: #{plan} - #{target_stage}"
    lc_info = @rest.get("plans", plan_id)
    lc_stage_id = -1
    lc_info["data"]["plan_template"]["stages"].each do |stage|
      lc_stage_id = stage["id"].to_i if stage["name"] == target_stage
    end
    if lc_stage_id > 0
      lc_attributes = {"plan_id" => plan_id, "plan_stage_id" => lc_stage_id}
    end
  else
    @rpm.log "\tPlan: not specified in calling request"
  end
else
  @rpm.log "\tPlan: No stage specified, cannot add to plan"
end
# Check the deployment windows for the environment
window = deployment_window(target_env_id)
execute_now = window.nil? && target_env_name != manual_environment
# now create the request
request_info = {"request" => {"name" => new_req_name, "environment_id" => target_env_id, "template_name" => template_name}}
request_info["request"]["plan_member_attributes"] = lc_attributes unless lc_attributes.nil?
request_info["request"]["data"] = @p.local_params
request_info["request"]["execute_now"] = true if execute_now
rest_result = @rest.create("requests", request_info)
# Test the results for success or failure
if rest_result["status"] == "success" && rest_result["data"].has_key?("id")
  #now grab the request_id from the results
  req_id = rest_result["data"]["id"]
  request_id = (req_id.to_i + 1000).to_s
  @rpm.message_box("Created Request: #{request_id} from rest")
  ensure_version_tags(rest_result, target_env_name)
  if wait_for_completion && execute_now
    result = @rest.monitor_request(req_id, "complete", monitor_options)
    @rpm.log "Result of request monitoring: #{result}"
  end
  @rpm.message_box("Created Request Results","sep")
  @rpm.log rest_result.to_json
  @rpm.log "Success test, rest call succeded: Success!"
  set_scheduled_request(req_id, window) unless window.nil?
else
  @rpm.log "Success test, Command_Failed"
end
# Flag the script for direct execution
params["direct_execute"] = true

