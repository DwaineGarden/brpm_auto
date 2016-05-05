# f2_rsc_reportingReleasePlans
###
# Report Period:
#   name: Optional if working from release plan
#   type: in-list-single
#   list_pairs: none,none|10,last_10_days|20,last_20_days|30,last_30_days|60,last_60_days|90,last_90_days
#   position: A2:C2
#   required: no
# Request States:
#   name: States to include in report
#   type: in-list-multi
#   list_pairs: complete,complete|cancelled,cancelled|problem,problem|hold,hold
#   position: A3:C3
#   required: no
###

#---------------------- Declarations ------------------------------#
@script_name_handle = "pipelineplans"
body = File.read(File.join(FRAMEWORK_DIR,"lib","resource_framework.rb"))
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
  
  
#---------------------- Main Body --------------------------#
def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  pout = []
  script_params.each{|k,v| pout << "#{k} => #{v}" }
  log_it "Current Params:\n#{pout.sort.join("\n") }"
  begin
    timestamp = Time.now.strftime("%m/%d/%Y %H:%M:%S")
    since_date = (Time.now - (90 * 87600)).strftime("%Y-%m-%dT%H:%M:%S")
    get_request_params
    options = get_report_data_file
    options["title"] = get_option(script_params, "Report Title")
    options["title"] = "Pipeline Report on #{timestamp}" if options["title"] == ""
    options["date"] = timestamp
    period = get_option(script_params, "Report Period", "none" )
    options["period"] = period.gsub("last_","").gsub("_days","") unless period == "none"
    options["period"] = 90 if period == "none"
    states = get_option(script_params, "Request States")
    options["states"] = states unless states == ""
    log_it "Report Options\n#{options.inspect}"
    update_report_data_file(options)
    plans = Plan.where("aasm_state = 'started' or (aasm_state = 'complete' and updated_at > '#{since_date}')").order("name")
    hsh = {}
    plans.each{|p| hsh[p.name] = p.id.to_s }
    log_it "PlanData\n#{hsh.inspect}"
    [hsh]
  rescue Exception => e
    log_it "#{e.message}\n#{e.backtrace}"
  end
end

def import_script_parameters
  { "render_as" => "List" }
end
 

