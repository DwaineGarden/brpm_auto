#  rsc_showPlanInfo.rb
#  Builds plan information into a table

#---------------------- Methods ---------------------------#
def plan_information(plan, options = {})
  apps = get_option(options, "apps", [])
  stages = get_option(options, "stages", [])
  report = []
  plan.plan_stages.each do |stage|
    if stages.empty? || stages.include?(stage.name)
      report << {"stage" => stage.name}
      components = []
      requests = stage.requests.include(:apps_requests).where("aasm_state IN ('complete, planned')").order("apps_requests.app_id, aasm_state, requests.id DESC")
      cur_app = ""; cur_env = ""
      request.each do |request|
        if request.app_name.first != cur_app
          report += components.sort{|a,b| a["component"] <=> b["component"] }
          report << {"app" => request.app_name.first, "environment" => request.environment.name }
          components = []
          cur_app = request.app_name.first
        end
        request_component_versions(request).each do |comp, ver|
          components << {"component" => comp, "version" => ver, "request" => request.number, "environment" => request.environment.name }
        end
      end
    end
  end
  report
end

# Description: 

def log_it(it)
  log_path = "/Users/brady/Documents/dev_rpm/logs"
  #log_path = "/tmp/logs"
  filename = "#{log_path}/output_planinfo_#{@params["SS_run_key"]}"
  txt = it.is_a?(String) ? it : it.inspect
  write_to txt
  return unless File.exist?(log_path)
  fil = File.open(filename, "a")
  fil.puts txt
  fil.close
  `chmod 644 #{filename}`
end

def hashify_list(list)
  response = {}
  list.each do |item,val| 
    response[val] = item
  end
  return [response]
end

def create_request_params_file
	request_data_file_dir = File.dirname(@params["SS_output_dir"])
	request_data_file = "#{request_data_file_dir}/request_data.json"
	fil = File.open(request_data_file,"w")
	fil.puts "{\"request_data_file\":\"Created #{Time.now.strftime("%m/%d/%Y %H:%M:%S")}\"}"
	fil.close
	file_part = request_data_file[request_data_file.index("/automation_results")..255]
	data_file_url = "#{@params["SS_base_url"]}#{file_part}"
	write_to "Request Run Data: #{data_file_url}"
	request_data_file
end

def init_request_params
	request_data_file_dir = File.dirname(@params["SS_output_dir"])
	request_data_file = "#{request_data_file_dir}/request_data.json"
	sleep(2) unless File.exist?(request_data_file)
	unless File.exist?(request_data_file)
		create_request_params_file	
	end
	file_part = request_data_file[request_data_file.index("/automation_results")..255]
	data_file_url = "#{@params["SS_base_url"]}#{file_part}"
	write_to "Request Run Data: #{data_file_url}"
	request_data_file
end

def get_request_params
	# Uses a json document in automation_results to store free-form information
	cur = init_request_params
	#message_box("Current Request Data","sep")
	@request_params = JSON.parse(File.open(cur).read)
	@request_params.each{ |k,v| write_to("#{k} => #{v.is_a?(String) ? v : v.inspect}") }
	@orig_request_params = @request_params.dup
	@request_params
end

def get_other_request_params(other_request)
	# Uses a json document in automation_results to store free-form information
	request_data_file_dir = File.dirname(@params["SS_output_dir"])
	request_data_file_dir.gsub!("/#{@params["SS_request_number"]}","/#{other_request}")
	request_data_file = "#{request_data_file_dir}/request_data.json"
	request_params = JSON.parse(File.open(cur).read)
end

def save_request_params
	# Uses a json document in automation_results to store free-form information
	cur = init_request_params
	unless @orig_request_params == @request_params
		sleep(2) unless File.exist?(cur)
		fil = File.open(cur,"w+")
		fil.write @request_params.to_json
		fil.close
	end
end

def default_table(error_row = ["1","Error", "Skipped - set to no"])
	totalItems = 1
	table_entries = [["#","Status","Information"], error_row]
	per_page=10
	{:totalItems => totalItems, :perPage => per_page, :data => table_entries }
end	 

#-------------------------- MAIN -------------------------#
def execute(script_params, parent_id, offset, max_records)
	#returns all the environments of a component
  log_it "Starting Automation"
  begin
    get_request_params
    plan_id = @params["request_plan_id"]
    if plan_id.nil? || plan_id == ""
      return default_table(["1","Error","Request must be part of a plan"])
    end
    plan = Plan.find_by_id(plan_id)
    table_data = [["#","Item","Info"]]
    apps = []
    stages = plan.stages.each do |ps|
      requests = Request.in_stage_of_plan(plan_id, ps.id).map(&:id)
      AppsRequest.find_all_by_request_id(requests).each do |ar|
        apps << ["app_#{ar.app.id}", "App: #{ar.app.name}", ""] unless apps.map{|l| l[0] }.include?("app_#{ar.app.id}") || ar.app.name == "[default]"
      end
      table_data << ["ps_#{ps.id}", "Stage - #{ps.name}", "Reqs: #{requests.size}"]
    end
    apps.each{|l| table_data << l }
    log_it(table_data)
  rescue Exception => e
    log_it "Error: #{e.message}\n#{e.backtrace}"
  end
  return table_data
end

def import_script_parameters
  { "render_as" => "List" }
end

