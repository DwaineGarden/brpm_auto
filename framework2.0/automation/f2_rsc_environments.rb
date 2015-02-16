# f2_rsc_promotionEnvironments
# Presents a list of environments for promotions with some judgements about routing

#---------------------- Declarations ------------------------------#
FRAMEWORK_DIR = @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib") unless defined?(FRAMEWORK_DIR)
@script_name_handle = "envs"
body = File.open(File.join(FRAMEWORK_DIR,"lib","resource_framework.rb")).read
result = eval(body)

#---------------------- Methods ------------------------------#

#---------------------- Main Script ------------------------------#
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
