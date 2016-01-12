# BAA rest automation class
#  this also wraps the BAAUtilities that ships with BRPM
require 'savon'

class TransportBAA < BrpmAutomation

  # Initializes the instance of the baa class
  #  this will authenticate to the Bladelogic server and
  #  perform an assume_role to the specified role
  # ==== Attributes
  #
  # * +url+ - url of the Bladelogic server
  # * +params+ - the params hash
  # * +options+ - hash of options, includes:
  #    +baa_username+ - user for Bladelogic account
  #    +baa_password+ - password for Bladelogic account
  #    +baa_role+ - role for Bladelogic account
  #
  def initialize(baa_url, params, options = {})
    @url = baa_url
    @username = get_option(options, "baa_username")
    @password = get_option(options, "baa_password")
    @role = get_option(options, "baa_role")
    super(params)
    if @password != ""
      @session_time = nil
      get_session_id      
      assume_role
    end
  end

  # Resets session and credentials
  #
  # ==== Attributes
  #
  # * +baa_username+ - username for baa
  # * +baa_password+ - password for baa
  # * +baa_role+ - role to assume (uses default role from class if ommitted)
  # ==== Returns
  #
  # * command output
  #
  def set_credential(baa_url, baa_username, baa_password, baa_role)
    @url = baa_url
    @username = baa_username
    @password = baa_password
    @role = baa_role
    @session_time = nil
    get_session_id      
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
          body_details = { :nameSpace => namespace, :commandName => command, :command_arguments => args}
          #body_details[:command_arguments] = args unless args.empty?
          soap.body = body_details
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
        body_details = { :nameSpace => namespace, :commandName => command }
        body_details[:command_arguments] = args unless args.empty?
        body_details.merge!({:payload => payload}) if payload
        soap.body = body_details
      end
    rescue Exception => e
      result = "ERROR: SoapError: #{e.message}\n#{e.backtrace}"
    end
    result = response.body[:execute_command_using_attachments_response][:return]
  end
  
  # Executes a BLCLI command with string arguments
  # Use this for simple commands like Server|listAllServers
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
  def execute_cli_command_by_string(namespace, command, args = [], options = {})
    begin
      response = nil
      check_session
      log "CLI: #{namespace}, #{command}, #{args.inspect}"
      client = Savon.client("#{@url}/services/BSACLITunnelService.wsdl") do |wsdl, http|
        http.auth.ssl.verify_mode = :none
      end
      client.http.read_timeout = get_option(options,"client_timeout",300)
      redirect_stdout do
        response = client.request(:execute_command_by_param_string) do |soap|
          soap.endpoint = "#{@url}/services/CLITunnelService"
          soap.header = {"ins1:sessionId" => @session_id}
          body_details = { :nameSpace => namespace, :commandName => command}
          body_details[:command_arguments] = args.join(",") unless args.empty?
          soap.body = body_details
        end
      end
      raw_result = response.body[:execute_command_by_param_string_response][:return]
      result = cli_result(raw_result)
    rescue Exception => e
      result = "ERROR: SoapError: #{e.message}\n#{e.backtrace}"
    end
    result
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
  # * +options+ - hash of options includes: 
  #   +path_property+ to abstract baa path ex.  path_property => BAA_BASE_PATH=/mnt/deploy/stage
  # this will substitute ??BAA_BASE_PATH?? for /mnt/deploy/stage in the added template part
  # ===== (see BLCLI documentation for Template|addDirectoryPart)
  #
  # ==== Returns
  #
  # * returnResult from CLI command
  #
  def add_template_content(template_dbkey, parts_hash, options = {})
    path_property = get_option(options, "path_property", nil)
    summary = nil
    parts_hash.each do |part, part_type|
      part = split_nsh_path(part)[1]
      if !path_property.nil? && path_property.include?("=")
        part = part.gsub(path_property.split("=")[1], "??#{path_property.split("=")[0]}??")
        log "\tAdding part: #{part}"
      end
      if part_type == "file"
        summary = add_file_to_template(template_dbkey, part, options)
      elsif part =~ /\.\w\w\w/
        summary = add_file_to_template(template_dbkey, part, options)
      elsif part.end_with?("/")
        summary = add_directory_to_template(template_dbkey, part, options)
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
      return "" if props.size == 0
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

  # Exports Job results for Deploy, Batch, NSH and Snapshot jobs to specified file
  #
  # ==== Attributes
  # * +job_folder+ - group folder of job
  # * +job_name+ - name of job
  # * +job_run_id+ - if of the job run
  # * +job_type+ - type of job (DeployJob, BatchJob, SnapshotJob, NSHScriptJob)
  # * +output_file+ - file to export to
  #
  # ==== Returns
  #
  # * returnResult from CLI command (BLCLI Utility|exportDeployRun)
  #
  def export_job_results(job_folder, job_name, job_run_id, job_type = "DeployJob", output_file = "default")
    status = []
    export_jobs = {"deployjob" => "exportDeployRun", "snapshotjob" => "exportSnapshotRun", "batchjob" => "exportBatchRun", "nshscriptjob" => "exportNSHScriptRun"}
    command_name = export_jobs[job_type.downcase]
    return "ERROR: job_type: #{job_type} doesnt match" if command_name.nil?
    export_name = "job_result_#{get_param(params, SS_request_id)}_#{get_param(params, SS_step_id)}"
    [".txt"].each do |ext|
      output_file = File.join(get_param(params, "SS_output_dir"), "#{export_name}.#{ext}")
      result = execute_cli_command_using_attachments("Utility", command_name, [job_folder, job_name, job_run_id, output_file])
      if result && (result.has_key?(:attachment))
        attachment = result[:attachment]
        csv_data = Base64.decode64(attachment)
        fil = File.open(output_file,"w+") do |fil|
          fil.write csv_data
          fil.flush
        end
        status << "Success #{ext}"
      else
        status << "Failed to export #{ext} results"
      end
    end
    status
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
      source_files.join(","), #source_files
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

  # Separates the server and path from an NSH path
  #  offers the option of embedding a property (blade-style) in lieu of the base_path
  #
  # ==== Attributes
  #
  # * +path+ - the nsh path
  # * +base_path+ - a path fragment to substitute with a property
  # * +path_property+ - a property name
  #
  # ==== Returns
  #
  # * the path portion of the nsh path
  # * if a property_name is passed, the return is like this:
  #    /opt/bmc/RLM/??DEPLOY_VERSION??/appserver
  def path_from_nsh_path(path, base_path = nil, path_property = nil)
    result = path
    result = "/#{result.split("/")[3..-1].join("/")}" if result.start_with?("//")
    unless path_property.nil?
      result = result.gsub(base_path, "??#{path_property}??")
    end
    result
  end

  # Returns the nsh path from a dos path
  #
  # ==== Attributes
  #
  # * +source_path+ - path in nsh
  # * +server+ - optional, adds a server in nsh format
  #
  # ==== Returns
  #
  # * nsh compatible path
  #
  def nsh_path(source_path, server = nil)
    path = ""
    if source_path.include?(":\\")
      path_array = source_path.split("\\")
      path = "/#{path_array[0].gsub(":","/")}"
      path += path_array[1..-1].join("/")
    else
      path = source_path
    end
    path = "//server#{path}" unless server.nil?
    path.chomp("/")
  end

  # Executes a batch job in BAA
  #
  # ==== Attributes
  #
  # * +job_name+ - name of job
  # * +group_path+ - path in Blade for job
  # * +targets+ - array of server targets (blank uses existing)
  # * +options+ - hash of options - includes target_type=server|group
  #
  # ==== Returns
  #
  # * job dbKey
  def execute_batch_job(job_name, group_path, targets = [], options = {})
    args = [group_path, job_name]
    ss_job_key = execute_cli_command("BatchJob","getDBKeyByGroupAndName",args)
    raise "Command_Failed: cannot find job: #{job_name} in #{group_path}" if ss_job_key.include?("ERROR")
    unless targets.blank?
      ss_job_key = execute_cli_command("Job","clearTargetServers",[ss_job_key])
      ss_job_key = execute_cli_command("Job","clearTargetGroups",[ss_job_key])
      ss_job_key = execute_cli_command("Job","addTargetGroups",[ss_job_key, targets]) if get_option(options,"target_type") == "group"
      ss_job_key = execute_cli_command("Job","addTargetServers",[ss_job_key, targets]) if get_option(options,"target_type") != "group"
    end 
    batch_job_key = execute_cli_command("BatchJob","executeJobAndWait",[ss_job_key])
    raise "Command_Failed: cannot create job: #{batch_job_key}" if batch_job_key.include?("ERROR")
    batch_job_key
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
    log "#=> Invoking BaaUtility method: #{destination} - #{args_new.inspect}"
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



