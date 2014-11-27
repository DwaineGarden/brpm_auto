
def log_it(it)
  #log_path = "/Users/brady/Documents/dev_rpm/logs"
  log_path = File.join(@params["SS_automation_results_dir"], "resource_logs")
  txt = it.is_a?(String) ? it : it.inspect
  write_to txt
  Dir.mkdir(log_path) unless File.exist?(log_path)
  fil = File.open("#{log_path}/output-env_#{@params["SS_run_key"]}", "a")
  fil.puts txt
  fil.close
end

def hashify_list(list)
  response = {}
  list.each do |item,val| 
    response[val] = item
  end
  return [response]
end

def execute(script_params, parent_id, offset, max_records)
  #returns all the environments of a component
  log_it "Starting Automation"
  begin
    envs = {}
    app = App.find_by_name(@params["SS_application"])
    routes = app.routes
    ipos = routes.map(&:name).index("General")
    route = routes[ipos] unless ipos.nil?
    route = routes[routes.map(&:name).index("[default]")]
    cur_pos = -1; promo = false; promo_env = ""; xtra = ""
    route.route_gates.each_with_index do |gate, idx|
      parallel = !gate.different_level_from_previous
      env_name = gate.environment.name
      if parallel
        xtra += "-alt" unless xtra.include?("must pass")
      elsif env_name == @params["SS_environment"]
        cur_pos = idx
        xtra = "- current"
      elsif cur_pos < 0
        xtra = "- not available"
      elsif idx > cur_pos && !promo
        promo = true
        xtra = "- promotion"
        promo_env = env_name
      else
        xtra = "- must pass #{promo_env}"
      end 
      envs[gate.environment_id.to_s] = "#{env_name} #{xtra}"
    end
    
    log_it envs
    result = hashify_list(envs)
    select_hash = {}
    select_hash["Select"] = ""
    result.unshift(select_hash)
    write_to result.inspect
    log_it(result)
  rescue Exception => e
    log_it "Error: #{e.message}\n#{e.backtrace}"
  end
  return result
end

def import_script_parameters
  { "render_as" => "List" }
end

