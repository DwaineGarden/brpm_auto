#  nsh_rscFileResults.rb
#  Displays the chosen files from tree picker
###
# pick a file:
#   type: in-text
#   position: A1:C1
#   name: argument
###

#---------------------- Methods ---------------------------#
# Description: 

def log_it(it)
  log_path = "/home/bbyrd/logs"
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
    cur_files = script_params["pick a file"]
    if cur_files.nil? || cur_files == ""
      return default_table(["1","Error","No files selected"])
    end
    table_data = [["#","Name","Path"]]
    @request_params["chosen_files"] = cur_files.inspect
    cur_files.each_with_index do |cur, idx|
       table_data << [idx, cur.split("|")[0], cur.split("|")[1]]
    end
    log_it(table_data)
    save_request_params
  rescue Exception => e
    log_it "Error: #{e.message}\n#{e.backtrace}"
  end
  return table_data
end

def import_script_parameters
  { "render_as" => "List" }
end

