# f2_rsc_templateUtilizationData
# Description: Resource to build reporting data

###
# Generate Report Data:
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
    "release_plans" => [147,2034],
    "applications" => [25,22,70],
    "states" => "complete,cancelled",
    "columns" =>
      [
      "App_id",
      "App", 
      "Template_id",
      "Template",
      "NumRequests",
      "Steps",
      "Environment",
      "AvgDuration"
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

def safe_date(date, return_string = true)
  return "" if date.nil? && return_string
  return 0 if date.nil? && !return_string  
  date.strftime("%m/%d/%y %H:%M:%S")
end

def templates_by_popularity_for_user_and_app(user, app_id)
  RequestTemplate.select("request_templates.id, request_templates.name, count(requests.id) as rank").unarchived.templates_for(user, app_id).joins("LEFT JOIN requests as child_requests on child_requests.origin_request_template_id = request_templates.id").group("request_templates.id, request_templates.name").order("rank DESC")
end

def average_duration(requests)
  durations = []
  requests.each{|req| durations << req.completed_at - req.started_at }
  avg = durations.inject{ |sum, el| sum + el }.to_f / durations.size
  return 0 if avg.nan?
  avg   
end

#---------------------- Main Body --------------------------#
def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  pout = []
  script_params.each{|k,v| pout << "#{k} => #{v}" }
  log_it "Current Params:\n#{pout.sort.join("\n") }"
  if script_params["Generate Report Data"] == "no"
    return default_table([["1","none","Choose Yes to generate data"]])
  end
  
  get_request_params
  begin
    @content = get_report_data_file
    log_it "Report Options\n#{@content.inspect}"
    if @content["applications"] == ""
      return default_table([["1","none","Select applications to continue"]])
    end
    @content["columns"] = base_options["columns"]
    @content["states"].each{|state| @content["columns"] << state unless @content["columns"].include?(state) }
    @content["templates"] = {}
    @content["applications"].each do |app_id|
      templates = templates_by_popularity_for_user_and_app(User.current_user, app_id)
      limit = 10
      @content["templates"][app_id] = templates[0..limit].map{|l| [l.id, l.name, l.rank, l.request.executable_steps.count] }
    end
    totals = {}
    table = []
    apps = App.find_all_by_id(@content["applications"])
    app_ids = apps.map(&:id)
    @content["templates"].each do |app_id, templates|
      app = apps[app_ids.index(app_id.to_i)]
      puts "#------ #{app.id}|#{app.name} -------------#"
      totals["#{app.id}|#{app.name}"] = {}
      templates.each do |template_info|
        totals["#{app.id}|#{app.name}"][template_info[0]] = {}
        puts "Template: #{template_info[1]}"
        env_result = Request.joins(:environment).select("distinct(environments.name)").functional.where("origin_request_template_id = #{template_info[0]}")
        env_result.map(&:name).each do |env|
          row = []
          row << app.id
          row << app.name
          row << template_info[0]
          row << template_info[1]
          row << template_info[2]
          row << template_info[3]
          puts "#------ #{env} -------------#"
          ave_duration = 0
          row << env
          row << ave_duration
          totals["#{app.id}|#{app.name}"][template_info[0]][env] = {}
          @content["states"].each do |state|
            if state == 'complete'
              recs = Request.joins(:environment).select("requests.id, started_at, completed_at").functional.where("origin_request_template_id = #{template_info[0]} AND environments.name = '#{env}' AND aasm_state = '#{state}'")
              ave_duration = average_duration(recs)
              res = recs.size
            else
              res = Request.joins(:environment).select("requests.id").functional.where("origin_request_template_id = #{template_info[0]} AND environments.name = '#{env}' AND aasm_state = '#{state}'").count
            end
            puts "State: #{state} => #{res}"
            row << res
            totals["#{app.id}|#{app.name}"][template_info[0]][env][state] = res
          end
          ipos = @content["columns"].index("AvgDuration")
          row[ipos] = ave_duration
          table << row
        end
      end
      
    end
    @content["data"] = {}
    @content["data"]["totals"] = totals
    @content["data"]["table"] = table
    update_report_data_file(@content)
    table_entries = [["", "Item", "Description"]]
    table_entries << [0, "Status", "Success"]
    table_entries << [0, "Total Templates", table.size]
    log_it(table_entries)
    totalItems = 3
    per_page = 10
    table_data = {:totalItems => totalItems, :perPage => per_page, :data => table_entries }
    table_data
  rescue Exception => e
    log_it "#{e.message}\n#{e.backtrace}"
  end
end


