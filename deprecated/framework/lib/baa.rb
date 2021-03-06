# BAA rest automation class
#  this also wraps the BAAUtilities that ships with BRPM
class BAA < BrpmAutomation

  # Initializes the instance of the baa class
  #  this will authenticate to the Bladelogic server and
  #  perform an assume_role to the specified role
  # ==== Attributes
  #
  # * +url+ - url of the Bladelogic server
  # * +baa_username+ - user for Bladelogic account
  # * +baa_password+ - password for Bladelogic account
  # * +baa_role+ - role for Bladelogic account
  # * +options+ - hash of options, includes output_file and nsh_path
  #
  def initialize(baa_url, baa_username, baa_password, baa_role, options = {})
    @url = baa_url
    @username = baa_username
    @password = baa_password
    @role = baa_role
    @session_time = nil
    get_session_id
    options = {"output_file" => options} if options.is_a?(String)
    output_file = get_option(options, "output_file")
    output_file = SS_output_file if get_option(options, "output_file") == ""
    super(output_file)
    assume_role
  end

  # Assumes the role (for SOAP only)
  #
  # ==== Attributes
  #
  # * +role+ - role to assume (uses default role from class if ommitted)
  # ==== Returns
  #
  # * command output
  #
  def assume_role(role = @role)
    @role = role
    BaaUtilities.baa_soap_assume_role(@url, role, @session_id)
  end

  # Gets a new session id via SOAP login
  #
  # ==== Returns
  #
  # * session_id
  #
  def get_session_id
    @session_id = BaaUtilities.baa_soap_login(@url, @username, @password)
    raise "Could not login to BAA Cli Tunnel Service" if @session_id.nil?
    @session_time = Time.now
  end

  # Returns current session id
  #
  # ==== Returns
  #
  # * session_id
  #
  def session_id
    @session_id
  end

  # Executes a BLCLI command
  #  (follow BLCLI docs)
  # ==== Attributes
  #
  # * +namespace+ - namespace of command
  # * +command+ - command to run
  # * +args+ - array of arguments to the command
  # * +options+ - hash of options includes: client_timeout (default is 300 seconds)
  #
  # ==== Returns
  #
  # * text result from command or "ERROR: SoapError" if failure
  # * logs to a special stderr file the verbose output in the step output folder
  #
  # ==== Examples
  #
  #  result = @baa.execute_cli_command("Server", "listAllServersInGroup", ["mysmartgroup"])
  #
  def execute_cli_command(namespace, command, args, options = {})
    begin
      response = nil
      check_session
      log "CLI: #{namespace}, #{command}, #{args.inspect}"
      client = Savon.client("#{@url}/services/BSACLITunnelService.wsdl") do |wsdl, http|
        http.auth.ssl.verify_mode = :none
      end
      client.http.read_timeout = get_option(options,"client_timeout",300)
      redirect_stdout do
        response = client.request(:execute_command_by_param_list) do |soap|
          soap.endpoint = "#{@url}/services/CLITunnelService"
          soap.header = {"ins1:sessionId" => @session_id}
          soap.body = { :nameSpace => namespace, :commandName => command, :commandArguments => args }
        end
      end
      raw_result = response.body[:execute_command_by_param_list_response][:return]
      result = cli_result(raw_result)
    rescue Exception => e
      result = "ERROR: SoapError: #{e.message}\n#{e.backtrace}"
    end
    result
  end

  # Executes a BLCLI command to return an attachment
  #
  # ==== Attributes
  #
  # * +namespace+ - namespace of command
  # * +command+ - command to run
  # * +args+ - array of arguments to the command
  #
  # ==== Returns
  #
  # * response_object hash which includes the attachment response["attachment"] base64 encoded
  #
  def execute_cli_command_using_attachments(namespace, command, args)
    payload = nil
    begin
      client = Savon.client("#{@url}/services/BSACLITunnelService.wsdl") do |wsdl, http|
        http.auth.ssl.verify_mode = :none
      end

      client.http.read_timeout = 300
      client.config.log = false
      response = client.request(:execute_command_using_attachments) do |soap|
        soap.endpoint = "#{@url}/services/CLITunnelService"
        soap.header = {"ins1:sessionId" => @session_id}
        body_details = { :nameSpace => namespace, :commandName => command, :commandArguments => args }
        body_details.merge!({:payload => payload}) if payload
        soap.body = body_details
      end
    rescue Exception => e
      result = "ERROR: SoapError: #{e.message}\n#{e.backtrace}"
    end
    result = response.body[:execute_command_using_attachments_response][:return]
  end

  # Returns the string for url and soap params
  #
  # ==== Attributes
  # * +obj_type+ - type of object [BlPackage,DeployJob,Template]
  # * +info_type+ - object or folder
  #
  # ==== Returns
  #
  # * string to use in url
  #
  def obj_to_url_item(obj_type, info_type = "folder")
    case obj_type
    when "BlPackage"
      return info_type == "folder" ? "Depot" : "Depot"
    when "DeployJob", "Jobs"
      return info_type == "folder" ? "Jobs" : "Job"
    when "Template"
      return info_type == "folder" ? "Component Templates" : "Template"
    else
      return obj_type
    end
  end

  # Gets the object in a group_path
  #
  # ==== Attributes
  # * +group_path+ - path to group
  # * +obj_type+ - base for group [DeployJob/BlPackage/ComponentTemplates]
  # * +return_contents+ - true to return a list of items in the group, false returns the full object
  # * +options+ - hash of options includes: verbose
  #
  # ==== Returns
  #
  # * array of group items or hash of group_object
  #
  def get_group_items(group_path, obj_type = "DeployJob", return_contents = true, options = {})
    group_path = "#{group_path}/" unless group_path.end_with?("/") if return_contents
    group_path = "/#{group_path}" unless group_path.start_with?("/")
    url = "#{@url}/group/#{obj_to_url_item(obj_type)}#{group_path}#{bl_auth}"
    result = rest_call(URI.escape(url), "get")
    log "RAW RESULT\n#{url}\n#{result.inspect}" if get_option(options,"verbose", false)
    return "ERROR: #{result["data"]["ErrorResponse"]["Error"]}" if result["data"].has_key?("ErrorResponse")
  return [] if return_contents && result["data"]["GroupChildrenResponse"]["GroupChildren"]["PropertySetInstances"].nil? 
    return result["data"]["GroupChildrenResponse"]["GroupChildren"]["PropertySetInstances"]["Elements"] if return_contents
    return result["data"]
  end

  # Verifies that a path exists
  #
  # ==== Attributes
  # * +group_path+ - path to group
  # * +obj_type+ - base for group [DeployJob/BlPackage/ComponentTemplates]
  #
  # ==== Returns
  #
  # * group_id or "ERROR"
  #
  def group_path_exists(group_path, obj_type = "Jobs")
    res = get_group_items(group_path, obj_type, false)
    return("ERROR") if res.is_a?(String) && res.start_with?("ERROR")
    group_id = res["GroupResponse"]["Group"]["groupId"]
    group_id
  end

  # Ensures that a group_path exists, will create if necessary
  #
  # ==== Attributes
  # * +group_path+ - path to group
  # * +obj_type+ - base for group [DeployJob/BlPackage/ComponentTemplates]
  #
  # ==== Returns
  #
  # * hash of group_object or "ERROR"
  #
  def ensure_group_path(group_path, obj_type = "Jobs")
    result = nil; create_result = nil
    cur_path = group_path.dup
    path_exists = false
    parts = group_path.split("/")
    not_there = []
    until path_exists
      cur_path = group_path.gsub(not_there.reverse.join("/"),"").chomp("/")
      result = group_path_exists(cur_path, obj_type)
      if result == "ERROR"
        log "#{cur_path} - not present"
        not_there << cur_path.split("/")[-1]
        log "NotThere: #{not_there.join(",")}"
      else
        path_exists = true
      end
    end
    log "#{cur_path} - Found"
    not_there.reverse.each do |item|
      cur_path += "/#{item}"
      create_result = create_group(item, result, obj_type)
      log "Creating: #{cur_path} => #{create_result}"
      result = create_result
    end
    create_result.nil? ? result : create_result
  end

  # Creates a group inside a parent group
  #
  # ==== Attributes
  # * +group_path+ - path to group
  # * +parent_id+ - group id of parent group
  # * +obj_type+ - base for group [DeployJob/BlPackage/ComponentTemplates]
  #
  # ==== Returns
  #
  # * array of group items or hash of group_object
  #
  def create_group(group_name, parent_id, obj_type = "Job")
    # Job, Template, Depot
    namespace = "#{obj_to_url_item(obj_type, "other")}Group"
    command = "create#{obj_to_url_item(obj_type, "other")}Group"
    args = [
      group_name,
      parent_id,
      ]
    result = execute_cli_command(namespace, command, args)
  end

  # Adds a file part to a ComponentTemplate
  #
  # ==== Attributes
  # * +template_dbkey+ - dbkey for component template
  # * +asset_path+ - path to file
  # * +options+ - hash of options includes: (see BLCLI documentation for Template|addFilePart)
  #
  # ==== Returns
  #
  # * returnResult from CLI command
  #
  def add_file_to_template(template_dbkey, asset_path, options = {})
    namespace = "Template"
    command = "addFilePart"
    args = [
      template_dbkey,
      asset_path,
      get_option(options, "b_includeLightChecksum" , false),
      get_option(options, "b_includeChecksum" , true),
      get_option(options, "b_includeFileAcls" , false),
      get_option(options, "b_copyfiles" , true),
      get_option(options, "b_auditFileSize" , false),
      get_option(options, "b_auditFileCreatedDate" , false),
      get_option(options, "b_auditFileModifiedDate" , false),
      get_option(options, "b_auditFilePermissions" , false),
      get_option(options, "b_auditFileUidGid" , false)
      ]
    result = execute_cli_command(namespace, command, args)
  end

  # Adds a directory to a ComponentTemplate
  #
  # ==== Attributes
  # * +template_dbkey+ - dbkey for component template
  # * +asset_path+ - path to directory
  # * +options+ - hash of options includes: (see BLCLI documentation for Template|addDirectoryPart)
  #
  # ==== Returns
  #
  # * returnResult from CLI command
  #
  def add_directory_to_template(template_dbkey, asset_path, options = {})
    namespace = "Template"
    command = "addDirectoryPart"
    args = [
      template_dbkey,
      asset_path,
      get_option(options, "b_includeLightChecksum" , false),
      get_option(options, "b_includeChecksum" , true),
      get_option(options, "b_includeFileAcls" , false),
      get_option(options, "b_recurse" , true),
      get_option(options, "b_copyfiles" , true),
      get_option(options, "b_auditFileSize" , false),
      get_option(options, "b_auditFileCreatedDate" , false),
      get_option(options, "b_auditFileModifiedDate" , false),
      get_option(options, "b_auditFilePermissions" , false),
      get_option(options, "b_auditFileUidGid" , false)
      ]
    result = execute_cli_command(namespace, command, args)
  end

  # Adds files and directories to a ComponentTemplate
  #
  # ==== Attributes
  # * +template_dbkey+ - dbkey for component template
  # * +part_array+ - array of paths to add to the template
  # * +options+ - hash of options includes: (see BLCLI documentation for Template|addDirectoryPart)
  #
  # ==== Returns
  #
  # * returnResult from CLI command
  #
  def add_template_content(template_dbkey, parts_hash, options = {})
  summary = nil
    parts_hash.each do |part, part_type|
      if part_type == "file"
        summary = add_file_to_template(template_dbkey, part, options)
      else
        summary = add_directory_to_template(template_dbkey, part, options)
      end
    end
    summary
  end

  # Creates an empty ComponentTemplate
  #
  # ==== Attributes
  # * +template_name+ - dbkey for component template
  # * +group_id+ - group_id of group_path
  #
  # ==== Returns
  #
  # * returnResult from CLI command (BLCLI Template|createEmptyTemplate)
  #
  def create_empty_template(template_name, group_id)
    namespace = "Template"
    command = "createEmptyTemplate"
    args = [
      template_name,
      group_id,
      true
      ]
    result = execute_cli_command(namespace, command, args)
  end

  # Creates a Component
  #
  # ==== Attributes
  # * +component_name+ - name of component
  # * +template_key+ - dbkey of ComponentTemplate
  # * +server_id+ - id of server to bind template
  #
  # ==== Returns
  #
  # * returnResult from CLI command (BLCLI Component|createComponent)
  #
  def create_component(component_name, template_key, server_id)
    namespace = "Component"
    command = "createComponent"
    args = [
      component_name,
      template_key,
      server_id
      ]
    result = execute_cli_command(namespace, command, args)
  end

  # Creates an empty Package in the Depot
  #
  # ==== Attributes
  # * +package_name+ - name of the package
  # * +group_id+ - group_id of group_path
  # * +options+ - hash of options, includes: "description"
  #
  # ==== Returns
  #
  # * returnResult from CLI command (BLCLI BlPackage|createEmptyPackage)
  #
  def create_empty_package(package_name, group_id, options = {})
    namespace = "BlPackage"
    command = "createEmptyPackage"
    args = [
      package_name,
      group_id,
      get_option(options, "description" , false)
      ]
    result = execute_cli_command(namespace, command, args)
  end

  # Gets the id of a server
  #
  # ==== Attributes
  # * +server_name+ - name of server
  #
  # ==== Returns
  #
  # * server_id (BLCLI - Server|getServerIdByName)
  #
  def get_server_id(server_name)
    namespace = "Server"
    command = "getServerIdByName"
    args = [
      server_name
      ]
    result = execute_cli_command(namespace, command, args)
  end

  # Creates a package from a component
  #
  # ==== Attributes
  # * +package_name+ - name for package
  # * +depot_group_id+ - group_id of group_path
  # * +template_id+ - id of ComponentTemplate
  # * +server_name+ - name of server to bind to template
  # * +options+ - hash of options (see BLCLI docs)
  #
  # ==== Returns
  #
  # * returnResult from CLI command (BLCLI BlPackage|createPackageFromComponent)
  #
  def create_component_package(package_name, depot_group_id, template_id, server_name, options = {})
    server_id = get_server_id(server_name)
    component_id = create_component(package_name, template_id, server_id)
    result = execute_cli_command("BlPackage", "createPackageFromComponent",
                [
                  package_name,       #packageName
                  depot_group_id,     #groupId
                  get_option(options, "bSoftLinked", true),                   #bSoftLinked
                  get_option(options, "bCollectFileAcl", false),              #bCollectFileAcl
                  get_option(options, "bCollectFileAttributes", false),       #bCollectFileAttributes
                  get_option(options, "bCopyFileContents", true),             #bCopyFileContents
                  get_option(options, "bCollectRegistryAcl", false),          #bCollectRegistryAcl
                  component_id,      #componentKey
                ])
  end

  # Creates a Job from a package
  #
  # ==== Attributes
  # * +job_name+ - name for job
  # * +job_group_id+ - group_id of group_path
  # * +servers+ - array of servers for job targets
  # * +options+ - hash of options (see BLCLI docs)
  #
  # ==== Returns
  #
  # * job_key from CLI command (BLCLI BlPackage|createDeployJob)
  #
  def create_package_job(job_name, job_group_id, package_id, servers, options = {})
    job_key = execute_cli_command("DeployJob", "createDeployJob",
                [
                  job_name,       #packageName
                  job_group_id,     #groupId
                  package_id,         # db_key
                  servers.first,
                  get_option(options, "isSimulateEnabled" , true),               #isSimulateEnabled
                  get_option(options, "isCommitEnabled" , true),              #isCommitEnabled
                  get_option(options, "isStagedIndirect" , false)             #isStagedIndirect
                ])
    if servers.size > 1
      add_target_servers(job_key, servers[1..-1])
    end
    job_key
  end

  # Adds server targets to a Job
  #
  # ==== Attributes
  # * +job_key+ - dbkey for job
  # * +servers+ - array of servers
  #
  # ==== Returns
  #
  # * job_key from CLI command (BLCLI Job|addTargetServers)
  #
  def add_target_servers(job_key, servers)
    job_key = execute_cli_command("Job", "addTargetServers",
                [
                  job_key,       # Jobkey
                  servers.join(",")    # serverslist
                 ])
    job_key
  end

  # Sets override package properties on a Job
  #
  # ==== Attributes
  # * +job_name+ - dbkey for component template
  # * +group_path+ - group_path
  # * +props+ - hash of name/values for properties to set
  #
  # ==== Returns
  #
  # * text of all property adds from CLI command (BLCLI DeployJob|setOverriddenParameterValue)
  #
  def set_job_properties(job_name, group_path, props)
    begin
      result = []
      log "Setting package properties on job:"
      props.each_pair do |prop,val|
        log "\t#{prop} => #{val}"
        result << execute_cli_command("DeployJob", "setOverriddenParameterValue",
                [
                    group_path,     #groupName
                    job_name,       #jobName
                    prop,           #parameterName
                    val     #valueAsString
                ])
      end
    rescue Exception => e1
      raise "Could not set property values: #{e1.message}"
    end
    result.join(",")
  end

  # Sets properties on a ComponentTemplate
  #
  # ==== Attributes
  # * +template_name+ - name for component template
  # * +group_path+ - group_path
  # * +props+ - hash of name/values for properties to set
  # * +options+ - hash of options (see BLCLI docs)
  #
  # ==== Returns
  #
  # * returnResult from CLI command (BLCLI Template|addLocalParameter)
  #
  def set_template_properties(template_name, group_path, props, options = {})
    begin
      result = nil
      log "Setting template properties:"
      props.each_pair do |prop,val|
        log "\t#{prop} => #{val}"
        result = add_template_property(template_name, group_path, prop, val, options)
      end
    rescue Exception => e1
      raise "Could not set property values: #{e1.message}"
    end
    result
  end

  # Sets a single property on a ComponentTemplate
  #
  # ==== Attributes
  # * +template_name+ - name for component template
  # * +group_path+ - group_path
  # * +property_name+ - name of property
  # * +property_value+ - value of property
  # * +options+ - hash of options (see BLCLI docs)
  #
  # ==== Returns
  #
  # * returnResult from CLI command (BLCLI Template|addLocalParameter)
  #
  def add_template_property(template_name, group_path, property_name, property_value, options = {})
    prop_key = execute_cli_command("Template", "addLocalParameter",
                [
                  template_name,       # Component template
                  group_path,         # template group
                  property_name,      #  Name of property
                  get_option(options, "description"),                 # property_description
                  "Primitive:/String", #property_type
                  get_option(options, "editable" , true),             # editable
                  get_option(options, "required", false),            # required
                  property_value    # value
                 ])
    prop_key
  end

  # Exports DeployJob results to specified file
  #
  # ==== Attributes
  # * +job_folder+ - group folder of job
  # * +job_name+ - name of job
  # * +job_run_id+ - if of the job run
  # * +output_file+ - file to export to
  #
  # ==== Returns
  #
  # * returnResult from CLI command (BLCLI Utility|exportDeployRun)
  #
  def export_deploy_job_results(job_folder, job_name, job_run_id, output_file = "/tmp/test.csv")
    result = execute_cli_command_using_attachments("Utility", "exportDeployRun", [job_folder, job_name, job_run_id, output_file])
    if result && (result.has_key?(:attachment))
      attachment = result[:attachment]
      csv_data = Base64.decode64(attachment)
      fil = File.open(output_file,"w+")
      fil.write csv_data
      fil.flush
      fil.close
      return "Success"
    else
      return "Failed to export results"
    end
    nil
  end

  # Packages passed references in BAA using a component template
  #  * note artifacts all need to reside on the same server
  #
  # ==== Attributes
  #
  # * +package_name+ - name for package (and template)
  # * +group_path+ - path in Blade to store package
  # * +artifacts+ - array of file/nsh paths
  # * +options+ - hash of options, includes:
  #    properties (hash of name/values to set),
  #    staging_server (default is first artifact server)
  #
  # ==== Returns
  #
  # * package_id
  def package_artifacts(package_name, group_path, artifacts, options)
    result = {"status" => "ERROR", "group_path" => group_path, "package_name" => package_name}
    artifact_hash = {}
    artifact_hash = artifacts if artifacts.is_a?(Hash)
    artifact_type = get_option(options, "artifact_type", "file")
    artifacts.each{|l| artifact_hash[l] = artifact_type } if artifacts.is_a?(Array)
    properties = get_option(options, "properties", nil)
    staging_server = get_option(options, "staging_server", nil)
    if staging_server.nil?
      pair = split_nsh_path(artifact_hash.keys.first)
      raise "Command_Failed: no staging server in options or artifacts" if pair[0].length < 2
      staging_server = pair[0]
    end
    result["staging_server"] = staging_server
    group_id = ensure_group_path(group_path, "Template")
    # group_items = get_group_items(group_path, "Template", true, options)
    templates_in_path = get_group_items(group_path, "Template", true, options)
    cur_templates = templates_in_path.map{|l| l["name"] }
    if cur_templates.include?(package_name)
      log "#=> Component Template exists: #{package_name}"
      template_id = templates_in_path[cur_templates.index(package_name)]["dbKey"]
    else # Create a new one
      log "#=> Create Component Template: #{package_name}"
      template_id = create_empty_template(package_name, group_id)
      log "\tApplying properties...to template with id #{template_id}" if properties
      template_id = set_template_properties(package_name, group_path, properties) if properties
    end
    log "\tAdd content to template #{template_id}\n"
    template_id = add_template_content(template_id, artifact_hash)
    result["template_db_key"] = template_id
    raise "Command_Failed: #{template_id}" if template_id.start_with?("ERROR")
    log "#=> Create component package: #{staging_server}\n"
    depot_group_id = ensure_group_path(group_path, "BlPackage")
    package_id = create_component_package(package_name, depot_group_id, template_id, staging_server)
    raise "Command_Failed: #{package_id}" if package_id.start_with?("ERROR")
    result["status"] = "SUCCESS"
    result["package_id"] = package_id
    result
  end
  
  # Deploys an existing Package in BAA to target servers
  #
  # ==== Attributes
  #
  # * +job_name+ - name for deploy job
  # * +package_id+ - id of existing package
  # * +group_path+ - path in Blade to store job
  # * +target_servers+ - array of file/nsh paths
  # * +options+ - hash of options, includes:
  #    execute_now - (true/false to execute the job immediately default - true)
  #    properties (hash of name/values to set),
  #
  # ==== Returns
  #
  # * hash of job results, includes - job_run_id, job_status
  def deploy_package(job_name, package_id, group_path, target_servers, options = {})
    execute_now = get_option(options,"execute_now",true)
    properties = get_option(options,"properties",{})
    result = {"status" => "ERROR"}
    log "#=> Building Job from Package:\n\tGroup: #{group_path}\n\tPackage: #{package_id}"
    log "#=> Mapping selected servers: #{target_servers.join(",")}"
    raise "ERROR: No servers found" if target_servers.empty?
    targets = baa_soap_map_server_names_to_rest_uri(target_servers)
    log "\tBuilding group path..."
    job_group_id = ensure_group_path(group_path, "Jobs")
    log "\tCreating package job..."
    cur_jobs = execute_cli_command("Job","listAllByGroup",[group_path])
    if cur_jobs.split("\n").include?(job_name)
      log "\tJob Exists: deleting..."
      ans = execute_cli_command("DeployJob","deleteJobByGroupAndName",[group_path, job_name])
    end
    job_db_key = create_package_job(job_name, job_group_id, package_id, target_servers)
    if job_db_key.start_with?("ERROR")
      log job_db_key
      raise "Command_Failed: job creation failed"
    end
    result["job_db_key"] = job_db_key
    result["status"] = "JOB_CREATED_SUCCESSFULLY"
    log "\tApplying properties..."
    prop_results = set_job_properties(job_name, group_path, properties)
    result["property_results"] = prop_results
    if execute_now
      log "#=> Executing Job"
      execute_results = execute_job_with_results(job_db_key, result)
      result["results"] = execute_results
    end
    result
  end

  # Creates an NSH Script Job in BAA to target servers
  #
  # ==== Attributes
  #
  # * +job_name+ - name for package (and template)
  # * +group_path+ - path in Blade for job
  # * +script_name+ - name of nsh script
  # * +script_group+ - path in depot to script
  # * +job_params+ - array of params (in order) for script job
  # * +targets+ - array of servers or smartgroups
  # * +options+ - hash of options, includes: execute_now and num_par_proces (max parallel processes), target_type (servers/groups)
  #
  # ==== Returns
  #
  # * hash of job results, includes - job_run_id, job_status
  def create_nsh_script_job(job_name, group_path, script_name, script_group, job_params, targets, options = {})
    result = {"status" => "ERROR"}
    job_type = "NSHScriptJob"
    num_par_procs = get_option(options,"num_par_procs", 50)
    execute_now = get_option(options,"execute_now", false)
    target_type = get_option(options,"target_type", "servers")
    args = [
      group_path, #jobGroup
      job_name,  #jobName
      "Script job from automation", #description
      script_group,
      script_name,
      num_par_procs # number of parallel processes
      ]
    ss_job_key = execute_cli_command(job_type,"createNSHScriptJob",args)
    raise "Command_Failed: cannot create job: #{ss_job_key}" if ss_job_key.include?("ERROR")
    log "Created: #{job_name} in group: #{group_path}"
    #targets.collect!{|k| k.gsub(/^\//,"/Servers/") unless k.start_with?("/Servers") }
    #c. Make the call to addTargetGroup (should be a new method)
    if targets.is_a?(String) || targets.size < 2
      method_call = target_type == "servers" ? "addTargetServer" : "addTargetGroup"
      servers = targets.first if targets.is_a?(Array)
    else
      method_call = target_type == "servers" ? "addTargetServers" : "addTargetGroups" 
      servers = targets.join(",")
    end
    ss_job_key = execute_cli_command("Job", method_call,
            [
              ss_job_key,       #jobName
              servers     #comma separated list of groups
            ]) 
    raise "Command_Failed: cannot add targets: #{ss_job_key}" if ss_job_key.include?("ERROR")
    if execute_now
      param_result = set_nsh_script_params(job_name, group_path, job_params, false)
      raise "Command_Failed: cannot set job parameters: #{param_result}" if param_result.include?("ERROR")
      execute_result = execute_job_with_results(param_result["job_db_key"], result)
      raise "Command_Failed: cannot execute job: #{execute_result.inspect}" if execute_result["status"].include?("ERROR")
    end
    result["job_db_key"] = ss_job_key
    result["status"] = "SUCCESS"
    result
  end

  # Executes an NSH Script Job in BAA to target servers
  #
  # ==== Attributes
  #
  # * +job_name+ - name for package (and template)
  # * +group_path+ - path in Blade for job
  # * +job_params+ - array of params (in order) for script job
  # * +targets+ - array of servers or smartgroups
  # * +target_type+ - server/group type of server target
  #
  # ==== Returns
  #
  # * hash of job results, includes - job_run_id, job_status
  def execute_nsh_script_job(job_name, group_path, job_params, targets, target_type = "server")
    result = {"status" => "ERROR"}
    job_type = "NSHScriptJob"
    ss_job_key = execute_cli_command(job_type,"getDBKeyByGroupAndName",[group_path, job_name])
    ss_job_key = execute_cli_command("Job","clearTargetServers",[ss_job_key]) if target_type == "server"
    ss_job_key = execute_cli_command("Job","clearTargetGroups",[ss_job_key]) if target_type != "server"
    raise "Command_Failed: cannot clear targets: #{ss_job_key}" if ss_job_key.include?("ERROR")
    ss_job_key = execute_cli_command("Job","addTargetServers",[ss_job_key,targets.join(",")])  if target_type == "server" && targets.count > 1
    ss_job_key = execute_cli_command("Job","addTargetGroups",[ss_job_key,targets.join(",")])  if target_type != "server" && targets.count > 1
    ss_job_key = execute_cli_command("Job","addTargetServer",[ss_job_key,targets.join])  if target_type == "server" && targets.count == 1
    ss_job_key = execute_cli_command("Job","addTargetGroup",[ss_job_key,targets.join])  if target_type != "server" && targets.count == 1
    raise "Command_Failed: cannot add targets: #{ss_job_key}" if ss_job_key.include?("ERROR")
    message_box("Executing NSHScript Job","title")
    log "#{job_name} in group: #{group_path}"
    param_result = set_nsh_script_params(job_name, group_path, job_params)
    raise "Command_Failed: cannot set job parameters: #{param_result}" if param_result.include?("ERROR")
    execute_result = execute_job_with_results(param_result["job_db_key"], result)
    raise "Command_Failed: cannot add targets: #{execute_result.insepct}" if execute_result["status"].include?("ERROR")
    result["result"] = execute_result
    result["status"] = "SUCCESS"
    result
  end

  # Executes a Job in BAA and returns detailed results
  #
  # ==== Attributes
  #
  # * +job_db_key+ - db_key of job
  # * +results+ - hash of existing results to add to
  #
  # ==== Returns
  #
  # * hash of job results, includes - job_run_id, job_status
  def execute_job_with_results(job_db_key, results = {})
    job_url = baa_soap_db_key_to_rest_uri(job_db_key)
    raise "Could not fetch REST URI for job: #{job_db_key}" if job_url.nil?
    job_result = execute_job(job_url)
    raise "Could run specified job, did not get a valid response from server" if job_result.nil?
    execution_status = "_SUCCESSFULLY"
    execution_status = "_WITH_WARNINGS" if (job_result["had_warnings"] == "true")
    if (job_result["had_errors"] == "true")
      execution_status = "_WITH_ERRORS"
      log("Job Execution failed: Please check job logs for errors")
    end
    results["status"] = job_result["status"] + execution_status
    job_run_url = job_result["job_run_url"]
    results["job_run_url"] = job_run_url
    job_run_id = get_job_run_id(job_run_url)
    results["job_run_id"] = job_run_id
    raise "Could not fetch job_run_id" if job_run_id.nil?
    job_result_url = get_job_result_url(job_run_url)
    raise "Could not fetch job_result_url" if job_result_url.nil?
    job_result = get_per_target_results(job_result_url)
    results["target_status"] = job_result
    results
  end

  # Sets parameters on an NSH Script Job in BAA
  #
  # ==== Attributes
  #
  # * +job_name+ - name for package (and template)
  # * +group_path+ - path in Blade for job
  # * +job_params+ - array of params (in order) for script job
  #
  # ==== Returns
  #
  # * hash of job results
  def set_nsh_script_params(job_name, group_path, job_params,clear_params=true)
    result = {"status" => "ERROR"}
    job_type = "NSHScriptJob"
    log "Executing NSH Script Job"
    log "Job: #{job_name}, In: #{group_path}"
    if clear_params
      log "\tRemove parameters"
      ss_job_key = execute_cli_command(job_type,"clearNSHScriptParameterValuesByGroupAndName",[group_path, job_name])
      raise "Command_Failed: cannot clear parameter values: #{ss_job_key}" if ss_job_key.include?("ERROR")
    end
    job_params.each_with_index do |param, idx|
      log "\tAdding param ##{idx}: #{param}"
      ss_job_key = execute_cli_command(job_type,"addNSHScriptParameterValueByGroupAndName",[group_path, job_name, idx, param])
      raise "Command_Failed: cannot clear parameter values: #{ss_job_key}" if ss_job_key.include?("ERROR")
    end
    result["job_db_key"] = ss_job_key
    result["status"] = "SUCCESS"
    result
  end

  # Creates a file deploy Job in BAA
  #
  # ==== Attributes
  #
  # * +job_name+ - name for package (and template)
  # * +group_path+ - path in Blade for job
  # * +source_files+ - array of files/directories to move
  # * +target_path+ - base path on target to deploy to
  # * +targets+ - array of servers/groups to deploy to
  # * +options+ - hash of options, includes: preserve_file_paths(true/false), num_par_procs=50, target_type=server, execute_now
  #
  # ==== Returns
  #
  # * hash of job results
  def create_file_deploy_job(job_name, group_path, source_files, target_path, targets, options = {})
    result = {"status" => "ERROR"}
    num_par_procs = get_option(options,"num_par_procs", 50)
    execute_now = get_option(options,"execute_now", false)
    target_type = get_option(options,"target_type", "server")
    preserve_file_paths = get_option(options,"preserve_file_paths", false)
    args = [
      job_name, #job_name
      group_path, #job_group
      source_files, #source_files
      target_path, #destination
      preserve_file_paths, #isPreserveSourceFilePaths
      num_par_procs, #numTargetsInParallel
      targets.join(","), #targetServerGroups
    ]
    log "Creating file deploy job: #{job_name} in: #{group_path}"
    job_db_key = execute_cli_command("FileDeployJob", "createJobByServerGroups", args) if target_type != "server"
    job_db_key = execute_cli_command("FileDeployJob", "createJobByServers", args) if target_type == "server"
    raise "Command_Failed: deploy job failed - #{job_db_key}" if job_db_key.include?("ERROR")
    result["job_db_key"] = job_db_key
    if execute_now
      log "#=> Executing Job"
      deploy_results_id = execute_cli_command("FileDeployJob", "executeJobAndWait", [job_db_key])
      raise "Command_Failed: deploy job failed - #{deploy_results_id}" if deploy_results_id.include?("ERROR")
      result["deploy_results_id"] = deploy_results_id
    end
    result["status"] = "SUCCESS"
    result
  end

  # Copies an NSHScriptJob in BAA to a new job
  #
  # ==== Attributes
  #
  # * +source_job+ - name for package (and template)
  # * +source_goup+ - path in Blade for job
  # * +target_job+ - array of files/directories to move
  # * +target_group+ - base path on target to deploy to
  #
  # ==== Returns
  #
  # * job dbKey
  def copy_job(source_job, source_group, target_job, target_group)
    args = [source_group, source_job]
    ss_job_key = execute_cli_command("NSHScriptJob","getDBKeyByGroupAndName",args)
    raise "Command_Failed: cannot find job: #{ss_job_key}" if ss_job_key.include?("ERROR")
    args = [ss_job_key, target_group, target_job]
    copy_job_key = execute_cli_command("Job","copyJob",args)
    raise "Command_Failed: cannot create job: #{copy_job_key}" if copy_job_key.include?("ERROR")
    copy_job_key
  end

  private

  def bl_auth
    "?username=#{@username}&password=#{@password}&role=#{@role}"
  end

  def method_missing(destination, *args)
    if destination.to_s.start_with?("baa_soap")
      check_session
      args_new = [@url, @session_id] + args
    else
      args_new = [@url, @username, @password, @role] + args
    end
    puts "#=> Invoking BaaUtility method: #{destination} - #{args_new.inspect}"
    result = BaaUtilities.send(destination, *args_new)
  end

  def redirect_stdout
    begin
      orig_stderr = $stderr.clone
      orig_stdout = $stdout.clone
      $stderr.reopen File.open("#{@output_file.gsub(".txt","")}_stdout.txt", 'a' )
      $stdout.reopen File.open("#{@output_file.gsub(".txt","")}_stderr.txt", 'a' )
      retval = yield
    rescue Exception => e
      $stdout.reopen orig_stdout
      $stderr.reopen orig_stderr
      raise e
    ensure
      $stdout.reopen orig_stdout
      $stderr.reopen orig_stderr
    end
    retval
  end

  def check_session
    if Time.now - @session_time > 300
      get_session_id
      assume_role
    end
    @session_id
  end

  def cli_result(raw_result)
    if raw_result && (raw_result.is_a? Hash)
      return "ERROR: Command execution failed: #{raw_result[:error]}, #{raw_result[:comments]}" if raw_result[:success] == false
      return raw_result[:return_value]
    else
      return "ERROR: Command execution did not return a valid response: #{raw_result.inspect}"
    end
    nil
  end

end

# Wrapper class for NSH interactions
class NSH < BrpmAutomation

  attr_writer :test_mode

  # Initialize the class
  #
  # ==== Attributes
  #
  # * +nsh_path+ - path to NSH dir on files system (must contain br directory too)
  # * +options+ - hash of options to use, send "output_file" to point to the logging file
  # * +test_mode+ - true/false to simulate commands instead of running them
  #
  def initialize(nsh_path, options = {}, test_mode = false)
    @nsh_path = nsh_path
    @test_mode = test_mode
    @verbose = get_option(options, "verbose", false)
    @max_time = get_option(options, "max_time", 3600)
    @opts = options
    @run_key = get_option(options,"timestamp",Time.now.strftime("%Y%m%d%H%M%S"))
    super(get_option(options,"output_file", nil))
    outf = get_option(options,"output_file", SS_output_file)
    @output_dir = File.dirname(outf)
    insure_proxy
  end

  # Verifies that proxy cred is set
  #
  # ==== Returns
  #
  # * blcred cred -acquire output
  def insure_proxy
    return true if get_option(@opts, "bl_profile") == ""
    res = get_cred
    puts res
  end

  # Displays any errors from a cred status
  #
  # ==== Attributes
  #
  # * +status+ - output from cred command
  #
  # ==== Returns
  #
  # * true/false
  def cred_errors?(status)
    errors = ["EXPIRED","cache is empty"]
    errors.each do |err|
        return true if status.include?(err)
    end
    return false
  end

  # Performs a cred -acquire
  #
  # ==== Returns
  #
  # * cred result message
  def get_cred
    bl_cred_path = File.join(@nsh_path,"bin","blcred")
    cred_status = `#{bl_cred_path} cred -list`
    puts "Current Status:\n#{cred_status}" if @test_mode
    if (cred_errors?(cred_status))
      # get cred
      cmd = "#{bl_cred_path} cred -acquire -profile #{get_option(@opts,"bl_profile")} -username #{get_option(@opts,"bl_username")} -password #{get_option(@opts,"bl_password")}"
      res = execute_shell(cmd)
      puts display_result(res) if @test_mode
      result = "Acquiring new credential"
    else
      result = "Current credential is valid"
    end
    result
  end

  # Runs an nsh script
  #
  # ==== Attributes
  #
  # * +script_path+ - path (local to rpm server) to script file
  #
  # ==== Returns
  #
  # * results of script
  def nsh(script_path, raw_result = false)
    cmd = "#{@nsh_path}/bin/nsh #{script_path}"
    cmd = @test_mode ? "echo \"#{cmd}\"" : cmd
    result = execute_shell(cmd)
    return result if raw_result
    display_result(result)
  end

  # Runs a simple one-line command in NSH
  #
  # ==== Attributes
  #
  # * +command+ - command to run
  #
  # ==== Returns
  #
  # * results of command
  def nsh_command(command, raw_result = false)
    path = create_temp_script("echo Running #{command}\n#{command}\n",{"temp_path" => "/tmp"})
    result = nsh(path, raw_result)
    File.delete path unless @test_mode
    result
  end

  # Copies all files (recursively) from source to destination on target hosts
  #
  # ==== Attributes
  #
  # * +target_hosts+ - blade hostnames to copy to
  # * +src_path+ - NSH path to source files
  # * +target_path+ - path to copy to (same for all target_hosts)
  #
  # ==== Returns
  #
  # * results of command
  def ncp(target_hosts, src_path, target_path)
    #ncp -vr /c/dev/SmartRelease_2/lib -h bradford-96204e -d "/c/dev/BMC Software/file_store"
    cmd = "#{@nsh_path}/bin/ncp -vrA #{src_path} -h #{target_hosts.join(" ")} -d \"#{target_path}\""
    cmd = @test_mode ? "echo \"#{cmd}\"" : cmd
    log cmd if @verbose
    result = execute_shell(cmd)
    display_result(result)
  end

  # Runs a command via nsh on a windows target
  #
  # ==== Attributes
  #
  # * +target_hosts+ - blade hostnames to copy to
  # * +target_path+ - path to copy to (same for all target_hosts)
  # * +command+ - command to run
  #
  # ==== Returns
  #
  # * results of command per host
  def nexec_win(target_hosts, target_path, command, options = {})
    # if source_script exists, transport it to the hosts
    max_time = get_option(options,"max_time", @max_time)
    result = "Running: #{command}\n"
    target_hosts.each do |host|
      cmd = "#{@nsh_path}/bin/nexec #{host} cmd /c \"cd #{target_path}; #{command}\""
      cmd = @test_mode ? "echo \"#{cmd}\"" : cmd
      result += "Host: #{host}\n"
      res = execute_shell(cmd, max_time)
      result += display_result(res)
    end
    result
  end

  # Runs a script on a remote server via NSH
  #
  # ==== Attributes
  #
  # * +target_hosts+ - blade hostnames to copy to
  # * +script_path+ - nsh path to the script
  # * +target_path+ - path from which to execute the script on the remote host
  # * +options+ - hash of options (raw_result = true, max_time in seconds to execute)
  #
  # ==== Returns
  #
  # * results of command per host
  def script_exec(target_hosts, script_path, target_path, options = {})
    max_time = get_option(options,"max_time", @max_time)
    raw_result = get_option(options,"raw_result", false)
    script_dir = File.dirname(script_path)
    err_file = touch_file("#{script_dir}/nsh_errors_#{Time.now.strftime("%Y%m%d%H%M%S%L")}.txt")
    out_file = touch_file("#{script_dir}/nsh_out_#{Time.now.strftime("%Y%m%d%H%M%S%L")}.txt")
    cmd = "#{@nsh_path}/bin/scriptutil -d \"#{target_path}\" -h #{target_hosts.join(" ")} -H \"Results from: %h\" -s #{script_path} 2>#{err_file} | tee #{out_file}"
    result = execute_shell(cmd)
    result["stdout"] = "#{result["stdout"]}\n#{File.open(out_file).read}"
    result["stderr"] = "#{result["stderr"]}\n#{File.open(err_file).read}"
    result = display_result(result) unless raw_result
    result
  end

  # Executes a text variable as a script on remote targets
  #
  # ==== Attributes
  #
  # * +target_hosts+ - array of target hosts
  # * +script_body+ - body of script
  # * +target_path+ - path on targets to store/execute script
  #
  # ==== Returns
  #
  # * output of script
  #
  def script_execute_body(target_hosts, script_body, target_path, options = {})
    script_file = "nsh_script_#{Time.now.strftime("%Y%m%d%H%M%S")}.sh"
    full_path = "#{File.dirname(SS_output_file)}/#{script_file}"
    fil = File.open(full_path,"w+")
    #fil.write script_body.gsub("\r", "")
    fil.flush
    fil.close
    result = script_exec(target_hosts, full_path, target_path, options)
  end

  # Runs a simple ls command in NSH
  #
  # ==== Attributes
  #
  # * +nsh_path+ - path to list files
  #
  # ==== Returns
  #
  # * array of path contents
  def nsh_dir(nsh_path)
    res = nsh_command("ls #{nsh_path}")
    res.split("\n").reject{|l| l.start_with?("Running ")}
  end

  # Provides a host status for the passed targets
  #
  # ==== Attributes
  #
  # * +target_hosts+ - array of hosts
  #
  # ==== Returns
  #
  # * hash of agentinfo on remote hosts
  def status(target_hosts)
    result = {}
    target_hosts.each do |host|
      res = nsh_command("agentinfo #{host}")
      result[host] = res
    end
    result
  end

  # Verifies file/directory for an array of items
  #  +this will preprocess any list of files/directories to pass to BAA::package_artifacts+
  #
  # ==== Attributes
  #
  # * +artifacts+ - array of file/nsh paths
  #
  # ==== Returns
  #
  # * hash of artifacts with a artifact_type {"/opt/bmc/file1.txt" => "file", "/opt/bmc" => "dir"}
  #
  def map_deploy_artifacts(artifacts)
    return_result = {}
    artifacts.each do |item|
      result = nsh_command("ls #{item.chomp("/") + "/"} > /dev/null",true)
      if result["stderr"] == ""
        ftype = "dir"
      elsif result["stderr"].include?("Not a directory")
        ftype = "file"
      else
        ftype = "error"
        raise "Command_Failed: path does not exist - #{item}"
      end
      return_result[item] = ftype
    end
    return_result
  end

  # Returns the dos path from an nsh path
  #
  # ==== Attributes
  #
  # * +nix_path+ - path in nsh
  #
  # ==== Returns
  #
  # * dos compatible path
  #
  def dos_path(nix_path)
    path = ""
    path_array = nix_path.split("/")
    if path_array[1].length == 1 # drive letter
      path = "#{path_array[1]}:\\"
      path += path_array[2..-1].join("\\")
    else
      path += path_array[1..-1].join("\\")
    end
    path
  end
  
  # Executes a command via shell in a timeout loop
  #
  # ==== Attributes
  #
  # * +platform_info+ - hash of plaform info e.g. {"transport" => "nsh", "platform" => "windows", "language" => "batch"}
  # ==== Returns
  #
  # * command_run hash {stdout => <results>, stderr => any errors, pid => process id, status => exit_code}
  def execute_shell(command, max_time = @max_time)
    cmd_result = {"stdout" => "","stderr" => "", "pid" => "", "status" => "1"}
    cmd_result["stdout"] = "Running #{command}\n"
    output_dir = File.join(@output_dir,"#{precision_timestamp}")
    errfile = "#{output_dir}_stderr.txt"
    cmd_result["stdout"] += "Script Output:\n"
    begin
      orig_stderr = $stderr.clone
      $stderr.reopen File.open(errfile, 'a' )
      timer_status = Timeout.timeout(max_time) {
        cmd_result["stdout"] += `#{command}`
        status = $?
        cmd_result["pid"] = status.pid
        cmd_result["status"] = status.to_i
      }
      stderr = File.open(errfile).read
      cmd_result["stderr"] = stderr if stderr.length > 2
    rescue Exception => e
      $stderr.reopen orig_stderr
      cmd_result["stderr"] = "ERROR\n#{e.message}\n#{e.backtrace}"
    ensure
      $stderr.reopen orig_stderr
    end
    File.delete(errfile)
    cmd_result
  end

  private

  def create_temp_script(body, options)
    script_type = get_option(options,"script_type", "nsh")
    base_path = get_option(options, "temp_path")
    tmp_file = "#{script_type}_temp_#{precision_timestamp}.#{script_type}"
    full_path = "#{base_path}/#{tmp_file}"
    fil = File.open(full_path,"w+")
    fil.puts body
    fil.flush
    fil.close
    full_path
  end
  
  def touch_file(file_path)
    fil = File.open(file_path,"w+")
    fil.close
    file_path
  end

end

