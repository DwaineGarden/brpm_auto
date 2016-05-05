# f2_rsc_reportingReleasePlans
###
# Release Plan:
#   name: Optional - choose a release plan
#   type: in-text
#   position: A4:D4
###
#

#---------------------- Declarations ------------------------------#
@script_name_handle = "pipelineapps"
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
    release_plans = get_option(script_params, "Release Plan")
    options = get_report_data_file
    options["release_plans"] = release_plans
    log_it "Report Options\n#{options.inspect}"
    update_report_data_file(options)
    if release_plans == "" || release_plans == "null"
      apps = App.apps_accessible_to_user(User.current_user).order("name")
    else
      apps = []
      release_plans.split(",").each do |l|
        Plan.find_by_id(l).plan_routes.each{|k| apps << k.route.app }
      end
    end
    hsh = {}
    apps.each{|p| hsh[p.name] = p.id.to_s }
    log_it "AppData\n#{hsh.inspect}"
    [hsh]
  rescue Exception => e
    log_it "#{e.message}\n#{e.backtrace}"
  end
end

def import_script_parameters
  { "render_as" => "List" }
end
 

