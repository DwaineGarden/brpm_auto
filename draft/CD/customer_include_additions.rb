#-------------------------------------------------------------------------#
#  Customer include additions for Regression Automation
#-------------------------------------------------------------------------#
# 5-4-15 BJB

def execute_library_action
  # Execute an action from the library
  step_name = @p.step_name
  msg = "Executing library action for step: #{step_name}\n"
  action_name = @p.get("Select Library Action")
  if action_name == ""
    action_name = "test/env_command.rb"
    library_action = File.join(ACTION_LIBRARY_PATH, action_name)
  else
    library_action = File.join(action_name.split("|")[1], action_name.split("|")[0])
  end
  msg += "Action: #{library_action}"
  @rpm.log msg
  conts = File.open(library_action).read
  eval conts
end