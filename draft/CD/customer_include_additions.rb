#-------------------------------------------------------------------------#
#  Customer include additions for Regression Automation
#-------------------------------------------------------------------------#
# 5-4-15 BJB

def execute_library_action
  # Execute an action from the library
  step_name = @p.step_name

  steps_config = YAML.load_file("#{File.dirname(__FILE__)}/steps_config.yml")

  raise "Step #{step_name} not configured" unless steps_config["steps"].has_key?(step_name)

  step_config = steps_config["steps"][step_name]

  script_name = step_config["script_name"]
  script_location = "#{File.dirname(__FILE__)}/#{script_name}.rb"

  if step_config.has_key?("input_params")
    step_config["input_params"].each do |key, value|
      @p.add(key, value)
    end
  end

  msg = "Executing library action for step: #{step_name}\n"
  msg += "Action: #{script_name}"
  @rpm.log msg

  script_content = File.open(script_location).read
  eval script_content
end