#---------------------- Add Request to Lifecycle -----------------------#
#    Launches a request and then puts it in the plan and stage
#
#---------------------- Arguments ---------------------------#
###
# request_template:
#   name: Name of request template 
#   type: in-text
#   position: A1:D1
#   required: yes
# promotion_environment:
#   name: Environment to promote to
#   type: in-external-single-select
#   position: A2:C2
#   external_resource: rsc_chooseEnvironment
#   required: no
# promotion_stage:
#   name: Stage to promote to 
#   type: in-text
#   position: A3:D3
#   required: yes
# wait_till_complete:
#   name: Wait for request to complete (optional - yes/no - default=no)
#   type: in-text
#   position: A4:D4
###

#---------------------- Declarations -----------------------#
# Flag the script for direct execution
params["direct_execute"] = true

token = params["SS_api_token"]
BaseURL = params["SS_base_url"]
if params.has_key?("include_path_ruby")
  tmp = params["include_path_ruby"]
  if File.exist?(tmp)
    require tmp
  else
  	write_to("Command_Failed: cant find include file: " + tmp)
  end
else
  write_to "This script requires a property: include_path_ruby"
  exit(1)
end

#---------------------- Variables -----------------------#
# Assign local variables to properties and script arguments
# BJB - take request param if available
calling_request = @p.get("calling_request", "none")
bypass_promotion = @p.get("bypass_promotion") == "yes" ? true : false
# BJB 9-20-12 To allow manual redeploy, always accept script arguments over the request_params if they exist
target_env = @p.get("ARG_promotion_environment")
target_env = @p.promotion_environment if @p.promotion_environment.downcase != "none"
target_stage = @p.get("ARG_promotion_stage")
target_stage = @p.promotion_stage
template_name = @p.get("ARG_request_template") == "" ? params["request_template"] : @p.get("ARG_request_template")
monitor_options = {"token" => token} # Note you can pass other options like {"monitor_step_name" => "database init", "max_time" => 60}
wait_for_completion = (@p.wait_till_complete == "yes")
send_request_data = (@p.send_request_data == "yes")
plan_member_id = @p.request_plan_member_id.to_i
if plan_member_id > 0
  plan = @p.request_plan
  plan_id = @p.request_plan_id.to_i
  plan_stage = @p.request_plan_stage
end  
new_req_name = "Promotion to #{target_stage}"
#---------------------- Methods -----------------------#

#---------------------- Main Routine -----------------------#
# 
if bypass_promotion # || if params["RBC-NG-Promote"] != "true"
	message_box "Skipping Promotion", "sep"
	write_to " Promotion property (or bypass) set to false"
	return 1
end

unless(target_env.nil? || target_env.length < 2 || template_name.length < 2)
  @p.assign_local_param("calling_request", @p.get("SS_request_number"))
  if target_stage.length > 1
	message_box("Launching Promotion Request","title")
	write_to "\tRequest Template: #{template_name}"
	write_to "\tEnvironment: #{target_env}"
	if plan_member_id > 0
		write_to "\Plan: #{plan} - #{target_stage}"
		lc_info = @rest.get("plans", plan_id)
	  
		#derive plan member for promotion
		# iterate through members till you find the target env
		lc_stage_id = -1
		#lc_info["response"]["plan"]["plan_template"]["stages"].each do |stage|
		lc_info["data"]["plan_template"]["stages"].each do |stage|
		  lc_stage_id = stage["id"].to_i if stage["name"] == target_stage
		end
		if lc_stage_id > 0
		  lc_attributes = {"plan_id" => plan_id, "plan_stage_id" => lc_stage_id}
		end
	else
		write_to "\tLifecycle: not specified in calling request"
	end
  else
		write_to "\tLifecycle: No stage specified, cannot add to plan"
  end
  # now create the request
  request_info = {"request" => {"token" => token, "name" => new_req_name, "environment" => target_env, "template_name" => template_name, "execute_now" => true}}
  request_info["request"]["plan_member_attributes"] = lc_attributes unless lc_attributes.nil?
  request_info["request"]["data"] = @request_params
  rest_result = @rest.create("requests", request_info)
  # Test the results for success or failure
	if rest_result["status"] == "success"
		#now grab the request_id from the results
		req_id = rest_result["data"]["id"]
		request_id = (req_id.to_i + 1000).to_s
		message_box("Created Request: #{request_id} from rest","title")
		if wait_for_completion
			result = monitor_request(req_id, monitor_options)
			write_to "Result of request monitoring: #{result}"
		end
		message_box("Created Request Results","sep")
		write_to rest_result.to_json
		write_to "Success test, rest call succeded: Success!"
	else
		write_to "Success test, Command_Failed"
	end
else
  write_to "Missing promotion environment or template name: Command_Failed"
end

# save_request_params # Important don't do this if other request modifies they will be over written

