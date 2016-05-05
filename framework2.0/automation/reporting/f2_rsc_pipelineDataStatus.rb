# Description: Resource to build reporting data

###
# Choose Applications:
#   name: Optional - default is all applications in plan/period
#   type: in-text
#   position: A5:D5
###
#---------------------- Declarations ------------------------------#
FRAMEWORK_DIR = @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib") unless defined?(FRAMEWORK_DIR)
@script_name_handle = "pipeline_data_status"
body = File.open(File.join(FRAMEWORK_DIR,"lib","resource_framework.rb")).read
result = eval(body)

#---------------------- Methods --------------------------------#
def base_options
  options = {
    "title" => "My Report",
    "period" => "none",
    "release_plans" => "147,2034",
    "applications" => "25,22,70",
    "states" => "complete,cancelled",
    "columns" =>
      [
      "Request_id",
      "Request", 
      "Start", 
      "Finish", 
      "State", 
      "App", 
      "Env", 
      "EnvironmentType", 
      "Owner", 
      "Plan", 
      "Stage", 
      "Component", 
      "Version", 
      "Step", 
      "State", 
      "Start", 
      "Finish", 
      "Executor", 
      "Ticket"
      ],
    "data" => 
      [
      ]
  }
end

def report_file
  File.join(@params["SS_output_dir"], "report_data.json")
end

def update_report_data_file(content)
  File.open(report_file, "w+") do |f|
    f.puts content.to_json
    f.flush
  end
end

def get_report_data_file
  if File.exist?(report_file)
    raw_content = File.read(report_file)
    content = JSON.parse(raw_content)
  end
  content ||= base_options
end

def step_owner(step)
  step.owner_type == "Group" ? Group.find_by_id(step.owner_id).try(:name) : User.find_by_id(step.owner_id).try(:name)
end

#---------------------- Main Body --------------------------#
def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  pout = []
  script_params.each{|k,v| pout << "#{k} => #{v}" }
  log_it "Current Params:\n#{pout.sort.join("\n") }"
  
  get_request_params
  begin
    @content = get_report_data_file
    @content["applications"] = get_option(script_params,"Choose Applications")
    @content["base_url"] = get_option(script_params,"SS_base_url")
    log_it "Report Options\n#{@content.inspect}"
    status = "ok"
    update_report_data_file(@content)
    table_entries = [["", "Item", "Description"]]
    table_entries << [0, "Status", status]
    table_entries << [1, "Title", @content["title"]]
    table_entries << [2, "Report Period", @content["period"]]
    table_entries << [3, "Request States", @content["states"]]
    table_entries << [4, "Release Plans", @content["release_plans"]]
    table_entries << [5, "Applications", @content["applications"]]
    log_it(table_entries)
    totalItems = 6
    per_page = 10
    table_data = {:totalItems => totalItems, :perPage => per_page, :data => table_entries }
    table_data
  rescue Exception => e
    log_it "#{e.message}\n#{e.backtrace}"
  end
end

 

