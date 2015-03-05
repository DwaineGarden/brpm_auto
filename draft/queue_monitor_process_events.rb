#require "#{File.dirname(__FILE__)}/../../../lib/brpm_rest_api"
#require "#{File.dirname(__FILE__)}/../../../lib/jira"
#require "#{File.dirname(__FILE__)}/jira_mappings"

def process_event(event)
  set_brpm_rest_api_url("http://localhost:#{ENV["EVENT_HANDLER_BRPM_PORT"]}/brpm")
  set_brpm_rest_api_token(ENV["EVENT_HANDLER_BRPM_TOKEN"])

  if event.has_key?("request")
    Logger.log  "The event is for a request #{event["event"][0]}..."
    process_request_event(event)
  end
end

def process_request_event(event)
  if  event["event"][0] == "update"
    request_old_state = event["request"].find { |item| item["type"] == "old" }
    request_new_state = event["request"].find { |item| item["type"] == "new" }

    if request_old_state["aasm-state"][0] != request_new_state["aasm-state"][0] or request_new_state["aasm-state"][0] == "complete" #TODO bug when a request is moved to complete the old state is also reported as complete
      Logger.log "Request '#{request_new_state["name"][0]}' moved from state '#{request_old_state["aasm-state"][0]}' to state '#{request_new_state["aasm-state"][0]}'"

      update_tickets_in_jira_by_request(request_new_state)
    end
  end
end

def update_tickets_in_jira_by_request(request)
  if request["aasm-state"][0] == "complete"
    Logger.log  "Getting the tickets that are linked to the request..."
    tickets = get_tickets_by_request_id(request["id"][0]["content"])

    if tickets.count == 0
      Logger.log "This request has no tickets, nothing further to do."
      return
    end

    Logger.log  "Getting the stage of this request..."
    request_with_details = get_request_by_id(request["id"][0]["content"])
    if request_with_details.has_key?("plan_member")
      stage_name = request_with_details["plan_member"]["stage"]["name"]

      Logger.log  "Getting the target status for the issues in JIRA..."
      target_issue_status = map_stage_to_issue_status(stage_name)

      unless target_issue_status.nil?
        Logger.log "Updating the status of the JIRA issues that correspond to the found tickets..."
        jira_client = Jira::Client.new(ENV["EVENT_HANDLER_JIRA_USERNAME"],
                                       ENV["EVENT_HANDLER_JIRA_PASSWORD"],
                                       ENV["EVENT_HANDLER_JIRA_URL"])

        Logger.log "Logging in to JIRA instance #{ENV["EVENT_HANDLER_JIRA_URL"]} with username #{ENV["EVENT_HANDLER_JIRA_USERNAME"]}..."
        jira_client.login()

        tickets.each do |ticket|
          Logger.log "Getting the possible transitions for ticket #{ticket["foreign_id"]}..."
          result = jira_client.get_issue_transitions(ticket["foreign_id"])

          transitions = result["transitions"]

          transition = transitions.find { |transition| transition["name"] == target_issue_status }

          if transition
            Logger.log "Issuing transition #{transition["name"]} to update the status to #{transition["to"]["name"]}..."
            issues = jira_client.post_issue_transition(ticket["foreign_id"], transition["id"], "Deployed with BRPM")
          else
            Logger.log "This ticket does not have a transition #{target_issue_status} currently. Leaving it in its current state."
          end
        end

        jira_client.logout()
      else
        Logger.log "No target issue ticket found so not processing the tickets."
      end
    else
      Logger.log "The request is not part of a plan so not processing the tickets."
    end
  end
end


