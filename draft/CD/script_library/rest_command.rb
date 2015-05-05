@rpm.message_box "Running REST commands", "title"
result = @rest.get("apps",,{"filters" => "filters[name]=#{@p.SS_application}"})
@rpm.log result.inspect
result = @rest.get("requests",(@p.request_id.to_i - 1000).to_s)
@rpm.log result.inspect
