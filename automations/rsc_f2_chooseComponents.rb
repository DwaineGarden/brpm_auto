# Description: Resource to choose the tech stack(components) for deployment
###
# Choose Components:
#   name: choose tech stack for deployment
#   type: in-text
#   position: A5:D5
#   required: yes
###

#----------------- Methods --------------------------------#
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

def save_request_params
  # Uses a json document in automation_results to store free-form information
  cur = init_request_params
  unless @orig_request_params == @request_params
    sleep(2) unless File.exist?(cur)
    fil = File.open(cur,"w+")
    fil.write @request_params.to_json
    fil.flush
    fil.close
  end
end

def default_table(other_rows = nil)
  totalItems = 1
  table_entries = [["#","Status","Information"]]
  table_entries << ["1","Error", "Insufficient Data"] if other_rows.nil?
  other_rows.each{|row| table_entries << row } unless other_rows.nil?
  per_page=10
  {:totalItems => totalItems, :perPage => per_page, :data => table_entries }
end  

def log_it(it)
  log_path = File.join(@params["SS_automation_results_dir"], "resource_logs")
  txt = it.is_a?(String) ? it : it.inspect
  write_to txt
  Dir.mkdir(log_path) unless File.exist?(log_path)
  fil = File.open("#{log_path}/output-rlm_#{@params["SS_run_key"]}", "a")
  fil.puts txt
  fil.close
end

#---------------------- Main Body --------------------------#
  
def execute(script_params, parent_id, offset, max_records)
  begin
    log_it("starting_automation\nScript Params\n#{script_params.inspect}")
    request = Request.find_by_id((@params["request_id"].to_i - 1000).to_s)
    get_request_params
    tech_stacks = []
    if script_params["Choose Components"] == "all"
      return default_table([["1","All","Deploying All"]])
    end
    app = App.find_by_name(@params["SS_application"])
    app.components.each do |comp|
      tech_stacks << comp.name unless ["General","[default]"].include?(comp.name)
    end
    if tech_stacks.empty?
        return default_table([["1","prop-RLM_TECH_STACKS",tech_stacks.inspect]])
    end
    table_entries = [["", "Component"]]
    tech_stacks.each_with_index do |comp,idx|
      table_entries << [comp.gsub(" ","_").downcase,comp]
    end
    log_it(table_entries)
    totalItems = tech_stacks.size
    per_page = 10
    table_data = {:totalItems => totalItems, :perPage => per_page, :data => table_entries }
    log_it(table_data)
    # Stuff some things in request_params for later
    @request_params["promotion_request_template"] = request.request_template_origin.try(:name)
    save_request_params
    return table_data
  rescue Exception => e
    log_it "Error: #{e.message}\n#{e.backtrace}"
  end
end
  
def import_script_parameters
  { "render_as" => "Table" }
end
