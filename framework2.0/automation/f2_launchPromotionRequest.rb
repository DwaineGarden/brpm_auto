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
# wait_till_complete:
#   name: Wait for request to complete (optional - yes/no - default=no)
#   type: in-list-single
#   list_pairs: yes,yes|no,no
#   position: A4:D4
###

#---------------------- Declarations -----------------------#

#---------------------- Variables -----------------------#
# Assign local variables to properties and script arguments
# BJB - take request param if available
calling_request = @p.get("calling_request", "none")
bypass_promotion = @p.get("bypass_promotion") == "yes" ? true : false
# BJB 9-20-12 To allow manual redeploy, always accept script arguments over the request_params if they exist
target_env = @p.get("promotion_environment")
target_env = @p.get("Promotion Environment") if @p.get("Promotion Environment") != ""
target_env_name = "next environment"
target_env_name = target_env.split("|")[1] if target_env.include?("|")
target_env = target_env.split("|")[0] if target_env.include?("|")
target_stage = @p.get("ARG_promotion_stage")
target_stage = @p.promotion_stage
template_name = @p.get("promotion_request_template", @p.get("request_template"))
monitor_options = {"max_time" => 60} # Note you can pass other options like {"monitor_step_name" => "database init", "max_time" => 60}
wait_for_completion = (@p.wait_till_complete == "yes")
send_request_data = (@p.send_request_data == "yes")
plan_member_id = @p.request_plan_member_id.to_i
if plan_member_id > 0
  plan = @p.request_plan
  plan_id = @p.request_plan_id.to_i
  plan_stage = @p.request_plan_stage
end  
new_req_name = "Promotion to #{target_env_name}. Stage: #{target_stage}"
#---------------------- Methods -----------------------#

#---------------------- Main Routine -----------------------#
# 
if bypass_promotion # || if params["RBC-NG-Promote"] != "true"
  @rpm.message_box "Skipping Promotion", "sep"
  @rpm.log " Promotion property (or bypass) set to false"
  return 1
end

if(target_env.nil? || target_env.length < 1 || template_name.length < 2)
  @rpm.message_box("Missing promotion environment or template name: Command_Failed", "title")
  exit(1)
end
@p.assign_local_param("calling_request", @p.get("SS_request_number"))
if target_stage.length > 1
  @rpm.message_box("Launching Promotion Request","title")
  @rpm.log "\tRequest Template: #{template_name}"
  @rpm.log "\tEnvironment: #{target_env}"
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
# now create the request
request_info = {"request" => {"name" => new_req_name, "environment_id" => target_env, "template_name" => template_name, "execute_now" => true}}
request_info["request"]["plan_member_attributes"] = lc_attributes unless lc_attributes.nil?
request_info["request"]["data"] = @p.local_params
rest_result = @rest.create("requests", request_info)
# Test the results for success or failure
if rest_result["status"] == "success"
  #now grab the request_id from the results
  req_id = rest_result["data"]["id"]
  request_id = (req_id.to_i + 1000).to_s
  @rpm.message_box("Created Request: #{request_id} from rest")
  if wait_for_completion
    result = @rest.monitor_request(req_id, "complete", monitor_options)
    @rpm.log "Result of request monitoring: #{result}"
  end
  @rpm.message_box("Created Request Results","sep")
  @rpm.log rest_result.to_json
  @rpm.log "Success test, rest call succeded: Success!"
else
  @rpm.log "Success test, Command_Failed"
end

# Flag the script for direct execution
params["direct_execute"] = true

