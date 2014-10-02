
#---------------------- Constants -------------------------#
  Jira_custom_fields = {
    "customfield_10722" => "build_version",
    "customfield_11728" => "build_url",
    "customfield_11526" => "requestor",
    "customfield_11729" => "svn_revision",
    "customfield_11746" => "config_changes",
    "customfield_11747" => "db_changes",
    "customfield_11734" => "related_tickets"
  }

  JiraTicketTypes = {
    "196" => "Build", 
    "197" => "Deploy", 
    "100" => "Incident", 
    "119" => "Release", 
    "3" => "Task"
  }

# Class for Interacting with Jira
class Jira < BrpmRest
  
  
  # Intialize the instance of the Jira class
  #
  # ==== Attributes
  #
  # * +options+ - send any options you would need for BrpmRest ("output_file")
  # * Make sure the integration constants are set in the automation
  # * Note: set the custom fields and ids for your Jira in the header of this file
  #
  def initialize(options = {})
    @base_url = get_option(options, "url", SS_integration_dns)
    @username = get_option(options, "username", SS_integration_username)
    @password = get_option(options, "password", decrypt_string_with_prefix(SS_integration_password_enc))
    @login_options = {"username" => @username, "password" => @password}
    super(@base_url, options)
  end
  
  def custom_fields
    Jira_custom_fields
  end

  def ticket_type(type_id)
    JiraTicketTypes.keys.include?(type_id) ? types["type_id"] : "Unknown"
  end

  def get_custom_field_ids
    reverse = {}
    Jira_custom_fields.each{ |k,v| reverse[v] = k }
    reverse
  end

  # Returns the custom fields from an issue
  #
  # ==== Attributes
  # * +issue+ - jira issue hash
  #
  # ==== Returns
  #
  # * array of custom field hashes
  #
  def get_custom_fields(issue)
    custom_items = {}
    issue.customFieldValues.each do |custom|
      if Jira_custom_fields.has_key?(custom.customfieldId)
        custom_items[Jira_custom_fields[custom.customfieldId]] = custom.values.join(", ")
      end
    end
    custom_items
  end

  # Returns a ruby date object from a Jira date
  #
  # ==== Attributes
  # * +date_str+ - Jira date string
  #
  # ==== Returns
  #
  # * ruby datetime
  #
  def format_date(date_str)
    ans = Date._parse(date_str, false).values_at(:year, :mon, :mday, :hour, :min, :sec, :zone, :wday)
    Time.mktime(*ans)
  end

  # Returns value of a jira field from the Issue
  #
  # ==== Attributes
  # * +issue+ - hash of Jira issue
  # * +field+ - field name to find
  #
  # ==== Returns
  #
  # * string 
  #
  def field(issue, field)
    res = ""
    issue = issue["data"] if issue.has_key?("data")
    if %w{issuetype status assignee reporter project}.include?(field)
      res = issue["fields"][field]["name"] unless issue["fields"][field].nil?
    elsif %w{duedate created updated}.include?(field)
      res = format_date(issue["fields"][field]).strftime("%m/%d/%Y") unless issue["fields"][field].nil?
    else
      res = issue["fields"][field] unless issue["fields"][field].nil?
    end
    res
  end

  # Performs a status transition on the Jira Issue
  #
  # ==== Attributes
  # * +issue_key+ - Jira issue key
  # * +transition_id+ - id for the status transition
  #
  # ==== Returns
  #
  # * string 
  #
  def status_transition(issue_key, transition_id)
    url = "#{@base_url}/rest/api/2/issue/#{issue_key}/transitions"
    comment = "Setting transition to #{transition_id} resolved"
    log "Available Transitions:"
    trannys = []
    result = rest_call(url, "get", @login_options)
    result["response"]["transitions"].each do |tran|
      trannys << tran["id"]
      log "#{tran["id"]}: #{tran["name"].ljust(10)} => #{tran["to"]["description"]}"
    end
    if trannys.include?(transition_id)
      log "\nSetting to: id=#{transition_id}"
      post = {"transition" => { "id" => transition_id}}
      options = [@login_options, {"data" => post}].inject(:merge)
      result = rest_call(url, "post", options)
      log result.inspect
    else
      log  "Command_Failed: Invalid transition for issue"
    end
    result
  end

  # Queries a Jira Issue
  #
  # ==== Attributes
  # * +issue_key+ - Jira issue key
  #
  # ==== Returns
  #
  # * jira result 
  #
  def get_issue(issue_key)
    url = "#{@base_url}/rest/api/2/issue/#{issue_key}"
    result = rest_call(url, "get", @login_options)
    log result.inspect
    result
  end


  # Adds a comment to the Jira Issue
  #
  # ==== Attributes
  # * +issue_key+ - Jira issue key
  # * +comment+ - comment to add
  #
  # ==== Returns
  #
  # * jira result 
  #
  def add_comment(issue_key, comment)
    url = "#{@base_url}/rest/api/2/issue/#{issue_key}/comment"
    post = {"body" => comment}
    options = [@login_options, {"data" => post}].inject(:merge)
    result = rest_call(url, "post", options)
    log result.inspect
    result
  end

  # Searches Jira issues with a jql string
  #
  # ==== Attributes
  # * +jql_criteria+ - Jira query language string
  #
  # ==== Returns
  #
  # * jira result 
  #
  def query_issues(jql_criteria)
    url = "#{@base_url}/rest/api/2/search"
    jql_criteria["maxResults"] = "5"
    comment = "Searching Issues via jql: #{jql_criteria.inspect}"
    options = [@login_options, {"data" => jql_criteria}].inject(:merge)
    result = rest_call(url, "post", options)
    #log result.inspect
    result
  end
end
