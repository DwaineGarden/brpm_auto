# Test RPM4.6 Using Watir
#  BJB 4/6/15
require 'rubygems'
require 'watir-webdriver'
require 'active_support/all'

@brpm_url = "http://ec2-54-208-221-146.compute-1.amazonaws.com:4005/brpm"
@echo = true
@logged_in = false
@timestamp = Time.now.strftime("%Y%m%d%H%M%S")

def init_log(run_name = "NewRun")
  cur_dir = File.dirname(File.expand_path(__FILE__))
  tstamp = Time.now.strftime("%Y%m%d%H%M%S")
  @log_file = File.join(cur_dir,"test_results_#{tstamp}.txt")
  fil = File.open(@log_file,"w+")
  msg = "#-------------------------------------------------------------#\n"
  msg += "#  New Test Run: #{run_name}  - #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}\n"
  msg += "#-------------------------------------------------------------#\n"
  msg += "Logging to: #{@log_file}"
  fil.puts msg
  puts msg if @echo
  fil.flush
  fil.close
end

def log(txt)
  fil = File.open(@log_file,"a")
  tstamp = Time.now.strftime("%H:%M:%S")
  txt.split("\n").each do |line|
    fil.puts "#{tstamp} | #{line}"
    puts "#{tstamp} | #{line}" if @echo
  end
  fil.flush
  fil.close
end

def test_login(user, password)
  @browser.goto @brpm_url
  log "Testing login screen (bbyrd/<password>)"
  @browser.text_field(:id => "user_login").set user
  @browser.text_field(:id => "user_password").set password
  @browser.button(:name => "commit").click
  raise "ERROR: failed login" if !@browser.title.include?("Dashboard")
  log "Directed to #{@browser.title}"
  @logged_in = true
  true
end

def test_applications(app_details)
  log "Testing Applications screen (#{app_details[:name]})"
  @browser.link(:text => "Applications").when_present.click
  if !@browser.title.include?("Applications")
    log "ERROR: No access to Applications"
    return false
  end
  @browser.link(:href => "/brpm/apps/new").when_present.click
  @browser.text_field(:id => "app_name").set app_details[:name]
  @browser.select_list(:id => "app_team_ids").select "AllAccess"
  @browser.button(:name => "commit").click
  raise "ERROR: failed to Create application" if !@browser.title.include?(app_details[:name])
  log "Directed to #{@browser.title}"
  log "Creating components/environments"
  environments = app_details[:environments].map{|k| k[:name]}
  environments.each do |env|
    @browser.link(:id => "add_remove_application_environment").when_present.click
    @browser.link(:text => "create new environment").when_present.click
    @browser.text_field(:id => "new_environments__name").set env
    @browser.form(:class => "add_remove_eg").submit
  end
   #@browser.button(:value => "Save").click
  #raise "ERROR: failed login" if !@browser.title.include?("Dashboard")
  log "Created environments: #{environments.join(",")}"
  
  components = environments = app_details[:components].map{|k| k[:name]}
  components.each do |comp|
    @browser.link(:id => "add_remove_application_component").when_present.click
    @browser.link(:text => "create new component").when_present.click
    @browser.text_field(:id => "new_components__name").set comp
    @browser.form(:class => "add_remove cssform").submit
  end
  #@browser.button(:value => "Save").click
  #raise "ERROR: failed login" if !@browser.title.include?("Dashboard")
  log "Created components: #{components.join(",")}"
  @browser.link(:text => "Copy All Components to All Environments").when_present.click
  if @browser.alert.exists?
    log "Confirming warning"
    @browser.alert.ok
  end
  log "Created #{app_details[:name]} successfully"
  true
end

def create_steps(step_details)
  num_steps = step_details.size - 1
  @browser.link(:text => "New Step").when_present.click
  step_details.each_with_index do |step, idx|
    log "Creating step: #{step[:name]}"
    @browser.text_field(:id => "step_name").when_present.set step[:name]
    @browser.text_field(:id => "step_description").set step[:description] if step[:description]
    if step[:component_name]
      @browser.select_list(:id => "step_component_id").select step[:component_name]
      if step[:automation_name]
        @browser.link(:text => "Automation", :href => "#").when_present.click
        @browser.select_list(:id => "automation_type").when_present.select "General"
        @browser.select_list(:id => "step_script_id").when_present.select step[:automation_name]
        @browser.text_field(:id => "script_argument_1").when_present.set step[:automation_argument_1] if step[:automation_argument_1]
        @browser.text_field(:id => "script_argument_2").when_present.set step[:automation_argument_2] if step[:automation_argument_2]
        @browser.text_field(:id => "script_argument_3").when_present.set step[:automation_argument_3] if step[:automation_argument_3]
        @browser.text_field(:id => "script_argument_4").when_present.set step[:automation_argument_4] if step[:automation_argument_4]
      end
    end
    if idx == num_steps
      @browser.button(:value => "Add Step & Close").click
    else
      @browser.button(:value => "Add Step & Continue").click
    end
  end
end

def create_requests(req_details)
  log "Testing Requests (#{req_details[:name]})"
  @browser.goto("#{@brpm_url}/requests/new")
  if !@browser.title.include?("Create")
    log "ERROR: No access to Create Request"
    return false
  end
  @browser.text_field(:id => "request_name").set req_details[:name]
  @browser.select_list(:id => "request_app_ids").select req_details[:app_name]
  @browser.select_list(:id => "request_environment_id").when_present.select req_details[:environment_name]
  @browser.select_list(:id => "request_plan_member_attributes_plan_id").when_present.select req_details[:plan_name] if req_details[:plan_name]
  @browser.select_list(:id => "request_plan_member_attributes_plan_stage_id").when_present.select req_details[:plan_stage_name] if req_details[:plan_stage_name]
  @browser.form(:id => "new_request").submit
  #@browser.button(:name => "commit").click
  cur_title = @browser.title
  if !cur_title.include?(req_details[:name])
    log "ERROR: Failed to Create Request"
    return false
  end
  items = cur_title.scan(/Request\s.*\s-/)
  request_id = items[0].gsub("Request","").gsub("-","").strip
  if create_steps(req_details[:steps])
    if req_details[:steps].size > 1
      log "Reordering Steps"
      @browser.link(:id => "reorder_steps").click
      steps = @browser.divs(:id => /step_.*/)
      steps[1].drag_and_drop_on steps[0].parent
      @browser.goto(File.join(@brpm_url,"requests" ,request_id ,"edit"))
    end
    log "Running request: #{request_id}"
    log "Planned State"
    @browser.link(:href => "/brpm/requests/#{request_id}/update_state/plan").when_present.click
    log "Started State"
    @browser.link(:href => "/brpm/requests/#{request_id}/update_state/start").when_present.click
  
    return true
  else
    return false
  end
end

#-------------------------------------------------------#
#       MAIN ROUTINE
#-------------------------------------------------------#

app_details = {
  :name => "new application_#{@timestamp}",
  :components => [
    {:name => "comp1_#{@timestamp}"},
    {:name => "comp2_#{@timestamp}"}
  ],
  :environments => [
    {:name => "env1_#{@timestamp}"},
    {:name => "env2_#{@timestamp}"}
  ]
}

request_details = {
  :name => "Test request",
  :app_name => app_details[:name],
  :environment_name => app_details[:environments][0][:name],
  :description => "Test requests with new application and 3 steps",
  :steps => [
    {:name => "First step automated", :component_name => app_details[:components][0][:name], :automation_name => "Direct_execute", :automation_argument_1 => "env", :automation_argument_2 => "PATH"},
    {:name => "Second step automated", :component_name => app_details[:components][1][:name], :automation_name => "Direct_execute", :automation_argument_1 => "dir", :automation_argument_2 => "app"},
    {:name => "Third step automated", :component_name => app_details[:components][0][:name], :automation_name => "Direct_execute", :automation_argument_1 => "cat config/torquebox.yml", :automation_argument_2 => "messaging"}
  ],
}


cur_run = ARGV[0] rescue nil
cur_run = "NewRun" if cur_run.nil?
init_log(cur_run)
log "Initializing Firefox (default browser)"
@browser = Watir::Browser.new
log "Using: #{@brpm_url}"

test_login("bbyrd", "bmcAdm1n")
app_name = "#{"NewApp"}_#{@timestamp}"
if test_applications(app_details)
  create_requests(request_details)
end