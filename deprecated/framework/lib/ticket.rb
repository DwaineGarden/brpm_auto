
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

class Client
  def initialize(user, pw, url)
    @username = user
    @password = pw
    @api_url  = "#{url}/rest/api/2"
    @auth_url = "#{url}/rest/auth/1"
  end
  
  attr_reader :username
  attr_reader :password
  attr_reader :cookie
  attr_reader :api_url
  attr_reader :auth_url
  
  # POST /auth/api/1/session
  def login()
    login = {:username => "#{@username}", :password => "#{@password}"}.to_json
    resp = post("#{@auth_url}/session", login)
    @cookie = resp.cookies
    @password = ''    # clear password as not needed once we login
  end
  
  # DELETE /auth/api/1/session
  def logout()
    resp = delete("#{@auth_url}/session")
    @cookie = ''
  end
  
  # POST /rest/api/2/issue/{issueIdOrKey}/comment
  def create_comment(issue_id, comment_body = 'Dummy Comment')
    cmmnt = {:body => comment_body}.to_json
    post_json("#{@api_url}/issue/#{issue_id}/comment", cmmnt)
  end
  
  # GET /rest/api/2/issue/{issueIdOrKey}/transitions[?transitionId={transistion_id}&expand=transitions.fields]
  def get_issue_transitions(issue_id, transition_id = "", expand_transition = false)
    url = "#{@api_url}/issue/#{issue_id}/transitions"
    # need to see if there is a cleaner way to implement the URL build
    added = false
    if not transition_id.eql? ""
      url = "#{url}?transitionId=#{transition_id}"
    end
    if expand_transition
      if added
        url = "#{url}&expand=transitions.fields"
      else
        url = "#{url}?expand=transitions.fields"
      end
    end
    get_json(url)
  end
  
  # POST /rest/api/2/issue/{issueIdOrKey}/transitions[?expand=transitions.fields]
  def post_issue_transition(issue_id, transition_id, comment = 'simple comment', expand_transition = false)
    url = "#{@api_url}/issue/#{issue_id}/transitions"
    if expand_transition
      url = "#{url}?expand=transitions.fields"
    end
    transition = {:update=>{:comment =>[{:add => {:body => "#{comment}"}}]}, :transition => {:id => "#{transition_id}"}}.to_json
                      #Simple post as only return code is returned
    post(url, transition)
  end
  
  # GET /rest/api/2/project
  def get_projects()
    get_json("#{@api_url}/project")
  end

  # GET /rest/api/2/search?jql=[Some Jira Query Language Search][&startAt=<num>&maxResults=<num>&fields=<field,field,...>&expand=<param,param,...>]
  def search(jql, start_at = 0, max_results = 50, fields = '', expand = '')
    url = "#{@api_url}/search?jql=#{jql}"
    url = "#{url}&startAt=#{start_at}" unless start_at == 0
    url = "#{url}&maxResults=#{max_results}" unless max_results == 50
    url = "#{url}&fields=#{fields}" unless fields == ''
    url = "#{url}&expand=#{expand}" unless expand == ''
    get_json(url)
  end
  
  # GET /rest/api/2/issue/{issueIdOrKey}[?fields=<field,field,...>&expand=<param,param,...>]
  def get_issue(issue_id, fields = '', expand = '')
    added = false
    url = "#{@api_url}/issue/#{issue_id}"
    if not fields.eql? ''
      url = "#{url}?fields=#{fields}"
      added = true
    end
    if not expand.eql? ''
      if added
        url = "#{url}&expand=#{expand}"
      else
        url = "#{url}?expand=#{expand}"
      end
    end
    get_json(url)
  end
  
private
  # JSON Styled RESTful GET
  def get_json(url)
    JSON.parse(get(url, :json, :json))
  end
  
  # JSON Styled RESTful POST
  def post_json(url, data)
    JSON.parse(post(url, data, :json, :json))
  end
  
  # JSON Styled RESTful PUT
  def put_json(url, data)
    JSON.parse(put(url, data, :json, :json))
  end
  
  # JSON Styled RESTful DELETE
  def delete_json(url)
    JSON.parse(delete(url, :json, :json))
  end
  
  # Build REST client that supports basic SSL with no cert verification (for use with private certs)
  def build_rest_client(url)
    RestClient::Resource.new(URI.encode(url), :verify_ssl => OpenSSL::SSL::VERIFY_NONE)
  end
  
  # RESTful GET request
  def get(url, content_type = :json, accept = :json)
    client = build_rest_client(url)
    client.get(:cookies => @cookie, :content_type => content_type, :accept => accept)
  rescue => e
    raise "GET Exception: Problem retrieving data (#{e.to_s})"
  end
  
  # RESTful POST request
  def post(url, data, content_type = :json, accept = :json)
    client = build_rest_client(url)
    client.post(data, :cookies => @cookie, :content_type => content_type, :accept => accept)
  rescue => e
    raise "POST Exception: Problem creating data (#{e.to_s})"
  end
  
  # RESTful PUT request
  def put(url, data, content_type = :json, accept = :json)
    client = build_rest_client(url)
    client.put(data, :cookies => @cookie, :content_type => content_type, :accept => accept)
  rescue => e
    raise "PUT Exception: Problem modifying data (#{e.to_s})"
  end
  
  # RESTful DELETE request
  def delete(url, content_type = :json, accept = :json)
    client = build_rest_client(url)
    client.delete(:cookies => @cookie, :content_type => content_type, :accept => accept)
  rescue => e
    raise "DELETE Exception: Problem removing data (#{e.to_s})"
  end
end