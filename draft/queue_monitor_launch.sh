#!/bin/bash
RLM_PATH=/opt/bmc/RLM4.6
.${RLM_PATH}/bin/setenv.sh

# mandatory settings
export EVENT_HANDLER_MESSAGING_PORT=5445
export EVENT_HANDLER_MESSAGING_USERNAME=msguser
export EVENT_HANDLER_MESSAGING_PASSWORD=testpwd1@
export EVENT_HANDLER_LOG_FILE=/tmp/event_handler.log
export EVENT_HANDLER_PROCESS_EVENT_SCRIPT=${RLM_PATH}/persist/automations/queue_monitor_process_event.rb

# custom settings
export EVENT_HANDLER_BRPM_PORT=4005
export EVENT_HANDLER_BRPM_TOKEN=

export EVENT_HANDLER_JIRA_URL=http://localhost:9090
export EVENT_HANDLER_JIRA_USERNAME=niek
export EVENT_HANDLER_JIRA_PASSWORD=


jruby ${RLM_PATH}/persist/automations/queue_monitor.rb
