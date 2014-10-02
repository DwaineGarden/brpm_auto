#---------------------- Add Request to Plan -----------------#
# Description: Launches a request and then puts it in the plan and stage
# Author(s): Brady Byrd, Cass Bishop, Scott Dunbar
#---------------------- Arguments ---------------------------#
###
# Plan Information:
#   name: Information table of plan items
#   type: in-external-single-select
#   external_resource: rsc_showPlanInfo
#   position: A1:F1
#   required: no
# Generate Plan Data:
#   name: Generates plan data from selections above 
#   position: A2:C2
#   type: in-list-single
#   list_pairs: Generate1,Generate1|Generate2,Generate2
#   required: no
# Plan Data:
#   name: Summary of plan data
#   type: in-external-single-select
#   position: A2:D2
#   external_resource: rsc_planPipelineReport
#   required: yes

#---------------------- Declarations -----------------------#
# Flag the script for direct execution

params["direct_execute"] = true
ruby_path = "/brpmout/persist/util_frameworkRubyInclude.rb"
if File.exist?(ruby_path)
    require ruby_path	 
else
  	write_to("Command_Failed: cant find frameworkRuby file: " + ruby_path)
end
get_request_params # Gathers request data from a json file, sets @request_params 

#---------------------- Methods -----------------------#
