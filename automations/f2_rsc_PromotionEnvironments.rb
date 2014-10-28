
def log_it(it)
  #log_path = "/Users/brady/Documents/dev_rpm/logs"
  log_path = "/home/bbyrd/logs"
  return unless File.exist?(log_path)
  fil = File.open("#{log_path}/output_#{@params["SS_run_key"]}", "a")
  fil.puts "ResourceAutomation Results:\n#{it.inspect}"
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
    temps = {}
    app = App.find_by_name(@params["SS_application"])
    app.environments.each do |env|
  		temps[env.id.to_s] = env.name
  	end
    log_it temps
  	result = hashify_list(temps)
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

