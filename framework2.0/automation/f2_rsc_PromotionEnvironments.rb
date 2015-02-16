# f2_rsc_promotionEnvironments
# Presents a list of environments for promotions with some judgements about routing

#---------------------- Declarations ------------------------------#
FRAMEWORK_DIR = @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib") unless defined?(FRAMEWORK_DIR)
body = File.open(File.join(FRAMEWORK_DIR,"lib","resource_framework.rb")).read
result = eval(body)
@script_name_handle = "promotion_envs"
load_customer_include(FRAMEWORK_DIR)
#---------------------- Methods ------------------------------#
def plan_route_constraints
  route_options = []; last_status = false
  return route_options if !@params.has_key?("request_plan_id") || @params["request_plan_id"].to_i < 1  
  cur_app = App.find_by_name(@params["SS_application"])
  plan = Plan.find_by_id(@params["request_plan_id"].to_i)
  cur_env = Environment.find_by_name(@params["SS_environment"])
  cur_stage = @params["request_plan_stage"]
  app_envs = {}
  cur_app.environments.each{|env| app_envs[env.name] = env.environment_type.try(:name)}
  plan.plan_stage_instances.sort{|a,b| a.plan_stage.position <=> b.plan_stage.position}.each do |ps|
    stage_info = {"stage" => ps.plan_stage.name, "environment_type" => ps.environment_type.try(:name)}
    if ps.plan_stage.name == cur_stage
      stage_status = "current"
      last_status = true
    else
      stage_status = "promote" if last_status
      last_status = false
    end
    if ps.environment_type.nil?
      env_list = ["open"]
    else
      log_it "PlanStageInstance: #{ps.plan_stage.name}: e-type: #{ps.environment_type.name}"
      env_list = []
      gates = ps.constraints.each do |gate|
        log_it "Gates: #{gate.constrainable.environment.name}-#{gate.constrainable.route.app.name}"
        env_list << gate.constrainable.environment.name if cur_app.name == gate.constrainable.route.app.name
      end
    end
    stage_info["environments"] = env_list
    stage_info["status"] = stage_status
    route_options << stage_info
  end
  log_it "RouteOptions: #{route_options}"
  route_options
end

#---------------------- Main Script ------------------------------#
def execute(script_params, parent_id, offset, max_records)
  #returns all the environments of a component
  log_it "Starting Automation"
  begin
    get_request_params
    envs = {}
    app = App.find_by_name(@params["SS_application"])
    routes = app.routes
    plan_options = plan_route_constraints
    app_route_options = []
    ipos = routes.map(&:name).index("Standard")
    route = routes[ipos] unless ipos.nil?
    ipos = routes.map(&:name).index("General") if ipos.nil?
    route = routes[ipos] unless ipos.nil?
    route = routes[routes.map(&:name).index("[default]")] if ipos.nil?
    cur_pos = -1; promo = false; promo_env = ""; xtra = ""
    route.route_gates.each_with_index do |gate, idx|
      stage = "none"
      parallel = !gate.different_level_from_previous
      env_name = gate.environment.name
      if env_name == @params["SS_environment"]
        cur_pos = idx
        xtra = "- status: current"
      elsif parallel
        xtra += " - alt" unless xtra.include?("must pass")
      elsif cur_pos < 0
        xtra = "- status: not available"
      elsif idx > cur_pos && !promo
        promo = true
        xtra = "- status: promotion"
        promo_env = env_name
      else
        xtra = "- status: must pass #{promo_env}"
      end 
      plan_options.each{|k| stage = k["stage"] if k["environments"].include?(env_name)}
      stage_stg = stage == "none" ? stage : " - stage: #{stage}"
      envs["#{gate.environment_id.to_s}|#{env_name}|#{stage}"] = "#{env_name}#{stage_stg}      #{xtra}"
      rt_info = {"environment_id" => gate.environment_id.to_s, "environment" => env_name, "environment_type" => gate.environment_type.name, "note" => xtra}
      rt_info["stage"] = stage if stage != "none"
      app_route_options << rt_info
    end
    log_it envs
    result = hashify_list(envs)
    select_hash = {}
    select_hash["Select"] = ""
    result.unshift(select_hash)
    write_to result.inspect
    @request_params["plan_route_options"] = plan_options unless plan_options == []
    @request_params["app_route_options"] = app_route_options
    save_request_params
    log_it(result)
  rescue Exception => e
    log_it "Error: #{e.message}\n#{e.backtrace}"
  end
  return result
end

def import_script_parameters
  { "render_as" => "List" }
end

