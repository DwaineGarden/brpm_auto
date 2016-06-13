#![.sh]/bin/bash

###
#
# COMMAND_TO_EXECUTE:
#   name: Source file path containing text to append
#   position: A1:F1
#   type: in-text
#
# TARGET_PATH:
#   name: Target file path to append to
#   position: A2:F2
#   type: in-text
#
###

#
# ExecuteCommand
#
#	Executes COMMAND_TO_EXECUTE in TARGET_PATH using dos batch
# 
<%= "echo \"Values of json_param = #{@p.promotion_environment}\"" %>
<% @p.environments.each do |k,v| %>
<%= "echo \"#{k} => #{v}\"" %>
<% end %>

echo "Executing $COMMAND_TO_EXECUTE"
if [[ -d $TARGET_PATH ]]
then
  cd $TARGET_PATH
fi
$COMMAND_TO_EXECUTE

