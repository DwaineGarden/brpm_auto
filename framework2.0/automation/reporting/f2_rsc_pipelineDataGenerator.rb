# Description: Resource to build reporting data

###
# Generate Plan Data:
#   name: Build Plan Data
#   type: in-list-single
#   list_pairs: no,no|yes,yes
#   position: A6:C6
###
#---------------------- Declarations ------------------------------#
FRAMEWORK_DIR = @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib") unless defined?(FRAMEWORK_DIR)
@script_name_handle = "pipeline_data"
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

def safe_date(date)
  return "" if date.nil?
  date.strftime("%m/%d/%y %H:%M:%S")
end

#---------------------- Main Body --------------------------#
def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  pout = []
  script_params.each{|k,v| pout << "#{k} => #{v}" }
  log_it "Current Params:\n#{pout.sort.join("\n") }"
  if script_params["Generate Plan Data"] == "no"
    return default_table([["1","none","Choose Yes to generate data"]])
  end
  
  get_request_params
  begin
    @content = get_report_data_file
    log_it "Report Options\n#{@content.inspect}"
    request_query = Request
    clauses = []
    if @content["applications"] != ""
      clauses << "apps_requests.app_id IN (#{@content["applications"].join(",")})"
      request_query = request_query.joins('INNER JOIN apps_requests ON apps_requests.request_id  = requests.id')
    end
    if @content["release_plans"] != "" && @content["release_plans"] != "null"
      clauses << "plan_members.plan_id IN (#{@content["release_plans"].join(",")})"
      request_query = request_query.joins('INNER JOIN plan_members ON plan_members.id  = requests.plan_member_id')
    end
    clauses << "started_at > '#{(Time.now - (86400 * @content["period"].to_i)).strftime("%Y-%m-%d")}'" if @content["period"].to_i > 0
    clauses << "aasm_state IN (#{@content["states"].map{|l| "'#{l}'" }.join(",")})"
    requests = request_query.functional.where(clauses.join(" AND "))
    log_it "Requests query: #{clauses.join(" AND ")}"
    return default_table([["1","none","No requests available with criteria"]]) if requests.size < 1
    steps = Step.where("request_id in (#{requests.map(&:id).join(",")}) and version_tag_id is not NULL").order("request_id, version_tag_id")
    step_data = []
    last_component = "zzzz"
    last_version = "zzzzz"
    steps.each do |step|
      next if ["locked", "ready", "hold"].include?(step.aasm_state)
      cur_component = step.component.name
      cur_version = step.version_tag.try(:name)
      row = []
      row << step.request.id
      row << step.request.name
      row << safe_date(step.request.started_at)
      row << safe_date(step.request.completed_at)
      row << step.request.aasm_state
      row << step.request.apps[0].name
      row << step.request.environment.name
      row << step.request.environment.environment_type.try(:name)
      row << step.request.owner.login
      row << step.request.plan.try(:name)
      row << step.request.plan_member.try(:stage).try(:name)
      row << cur_component
      row << cur_version
      row << step.name
      row << step.aasm_state
      row << safe_date(step.work_started_at)
      row << safe_date(step.work_finished_at)
      row << step_owner(step)
      row << step.tickets.present? ? step.tickets.map{|l| l.foreign_id }.join(",") : ""
      step_data << row if(cur_version != last_version || cur_component != last_component)
      last_component = cur_component
      last_version = cur_version
    end
    step_data
    @content["data"] = step_data
    update_report_data_file(@content)
    table_entries = [["", "Item", "Description"]]
    table_entries << [0, "Status", "Success"]
    table_entries << [0, "Total Requests", steps.map(&:request_id).uniq.size.to_s]
    table_entries << [0, "Total Steps", step_data.size.to_s]
    log_it(table_entries)
    totalItems = steps.size
    per_page = 10
    table_data = {:totalItems => totalItems, :perPage => per_page, :data => table_entries }
    table_data
  rescue Exception => e
    log_it "#{e.message}\n#{e.backtrace}"
  end
end


