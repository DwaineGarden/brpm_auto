# Description: Resource to choose the tech stack(components) for deployment
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 
###
# Choose Components:
#   name: choose tech stack for deployment
#   type: in-text
#   position: A5:D5
#   required: yes
###
#---------------------- Declarations ------------------------------#
FRAMEWORK_DIR = @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib") unless defined?(FRAMEWORK_DIR)

body = File.open(File.join(FRAMEWORK_DIR,"lib","resource_framework.rb")).read
result = eval(body)
@script_name_handle = "choose_comps"

#---------------------- Methods --------------------------------#

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
    if script_params["Choose Components"] == "none"
      return default_table([["1","none","No Components Chosen"]])
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
