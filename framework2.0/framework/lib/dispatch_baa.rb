# dispatch_srun.rb
#  Module for action dispatch with nsh protocol
libDir = File.expand_path(File.dirname(__FILE__))
require "#{libDir}/dispatch_base"


class DispatchBAA < DispatchBase
  # Initialize the class
  #
  # ==== Attributes
  #
  # * +baa_object+ - handle to an BAA object
  # * +options+ - hash of options to use, send "output_file" to point to the logging file
  # * +test_mode+ - true/false to simulate commands instead of running them
  #
  def initialize(baa_object, params, options = {})
    @baa = baa_object
    @verbose = get_option(options, "verbose", false)
    @params = params
    super(params)
    @output_dir = get_param("SS_output_dir")
  end
    
  # Packages passed references in BAA using a component template
  # --- note: artifacts all need to reside on the same server
  # --- note: end a directory path with a / or it will be treated as a file
  
  # ==== Attributes
  #
  # * +artifact_list+ - array of file/nsh paths
  # * +group_path+ - path in Blade to store package
  # * +artifacts+ - array of file/nsh paths
  # * +options+ - hash of options, includes:
  #    package_name - to override default package name (component_request_id_version),
  #    group_path - to override default group_path (app/version/component),
  #    transfer_properties - hash of properties to transfer
  #    version - to override use of component version
  #
  # ==== Returns
  #
  # * hash - {package_id, status, template_db_key, stagin_server}
  def package_artifacts(artifact_list, options = {})
    version = get_option(options,"version", get_param("step_version"))
    package_name = get_option(options, "package_name", default_item_name(version))
    group_path = get_option(options, "group_path", default_group_path(version))
    transfer_properties = get_option(options, "transfer_properties", {})
    path_property_name = get_option(options, "BAA_PATH_PROPERTY", "BAA_BASE_PATH")
    path_property_value = get_option(transfer_properties, path_property_name, nil)
    path_property = "#{path_property_name}=#{path_property_value}"
    message_box "Packaging Files via BAA"
    log "\t StagingPath: #{group_path}"
    result = {"status" => "ERROR", "group_path" => group_path, "package_name" => package_name}
    artifact_hash = {}
    artifact_list.each{|l| artifact_hash[l] = l.end_with?("/") ? "directory" : "file" }
    pair = split_nsh_path(artifact_hash.keys.first)
    raise "Command_Failed: no staging server in artifacts" if pair[0].length < 2
    staging_server = pair[0]
    result["staging_server"] = staging_server
    group_id = @baa.ensure_group_path(group_path, "Template")
    templates_in_path = @baa.get_group_items(group_path, "Template", true, options)
    cur_templates = templates_in_path.map{|l| l["name"] }
    if cur_templates.include?(package_name)
      log "#=> Component Template exists: #{package_name}"
      template_id = templates_in_path[cur_templates.index(package_name)]["dbKey"]
    else # Create a new one
      log "#=> Create Component Template: #{package_name}"
      template_id = @baa.create_empty_template(package_name, group_id)
      log "\tApplying properties...to template with id #{template_id}" if transfer_properties.size > 0
      template_id = @baa.set_template_properties(package_name, group_path, transfer_properties) if transfer_properties.size > 0
    end
    log "\tAdd content to template #{template_id}\nPath property: #{path_property}"
    template_options = {}
    template_options["path_property"] = path_property unless path_property_value.nil?
    template_id = @baa.add_template_content(template_id, artifact_hash, template_options)
    result["template_db_key"] = template_id
    raise "Command_Failed: #{template_id}" if template_id.start_with?("ERROR")
    log "#=> Create component package: #{staging_server}\n"
    depot_group_id = @baa.ensure_group_path(group_path, "BlPackage")
    package_id = @baa.create_component_package(package_name, depot_group_id, template_id, staging_server)
    raise "Command_Failed: #{package_id}" if package_id.start_with?("ERROR")
    result["status"] = "SUCCESS"
    result["path_property"] = path_property unless path_property_value.nil?
    result["package_id"] = package_id
    result["instance_path"] = "#{group_path}/#{package_name}"
    result["md5"] = "000"
    result
  end
  
  # Deploys an existing Package in BAA to target servers
  #
  # ==== Attributes
  #
  # * +package_id+ - id of existing package
  # * +options+ - hash of options, includes:
  #    job_name - to override the default job name,
  #    group_path - to override the default group path,
  #    execute_now - (true/false to execute the job immediately default - true),
  #    transfer_properties (hash of name/values to set),
  #    version - to override use of component version
  #
  # ==== Returns
  #
  # * hash of job results, includes - job_run_id, job_status
  def deploy_package_instance(package_info, options = {})
    package_id = package_info["package_id"]
    path_property = get_option(package_info,"path_property", nil)
    version = get_option(options,"version", get_param("SS_component_version"))
    execute_now = get_option(options,"execute_now", true)
    job_base_name = get_option(options, "job_name", default_item_name(version))
    group_path = get_option(options, "group_path", default_group_path(version, true))
    transfer_properties = get_option(options, "transfer_properties", {})
    unless path_property.nil?
      package_property = path_property.split("=")[0]
      deploy_property = "#{package_property}_DEPLOY"
      log "\t No corresponding deploy property for #{package_property} (should be #{deploy_property})", "WARN" if !transfer_properties.has_key?(deploy_property)
      transfer_properties[package_property] = transfer_properties[deploy_property] if transfer_properties.has_key?(deploy_property)
    end
    message_box "Packaging Files via BAA"
    log "\t StagingPath: #{group_path}"
    result = {"status" => "ERROR", "results" => "", "group_path" => group_path, "job_names" => []}
    raise "ERROR: No servers found" if get_server_list.empty?
    log "\tBuilding group path..."
    job_group_id = @baa.ensure_group_path(group_path, "Jobs")
    # Loop through the platforms
    OS_PLATFORMS.each do |os, os_details|
      servers = get_platform_servers(os)
      message_box "OS Platform: #{os_details["name"]}"
      log "No servers selected for: #{os_details["name"]}" if servers.size == 0
      next if servers.size == 0
      job_name = "#{job_base_name}_#{os}"
      result["job_names"] << job_name
      log "#=> Building Job from Package:\n\tGroup: #{group_path}\n\tPackage: #{package_id}"
      log "# #{os_details["name"]} - Targets: #{servers.inspect}"
      targets = @baa.baa_soap_map_server_names_to_rest_uri(server_dns_names(servers))
      log "\tCreating package job..."
      cur_jobs = @baa.execute_cli_command("Job","listAllByGroup",[group_path])
      if cur_jobs.split("\n").include?(job_name)
        log "\tJob Exists: deleting..."
        ans = @baa.execute_cli_command("DeployJob","deleteJobByGroupAndName",[group_path, job_name])
      end
      job_db_key = @baa.create_package_job(job_name, job_group_id, package_id, server_dns_names(servers))
      if job_db_key.start_with?("ERROR")
        log job_db_key
        raise "Command_Failed: job creation failed"
      end
      result["job_db_key"] = job_db_key
      result["status"] = "JOB_CREATED_SUCCESSFULLY"
      log "\tApplying properties..."
      prop_results = @baa.set_job_properties(job_name, group_path, transfer_properties)
      result["property_results"] = prop_results
      if execute_now
        log "#=> Executing Job"
        execute_results = @baa.execute_job_with_results(job_db_key, result)
        result["results"] += "#{os} - #{execute_results}"
        execute_results.each{|k,v| log("#{k}: #{v}")}
      end
    end
    result
  end

  # Creates an NSH Script Job in BAA to target servers
  #
  # ==== Attributes
  #
  # * +script_name+ - name of nsh script
  # * +script_group+ - path in depot to script
  # * +job_params+ - array of params (in order) for script job
  # * +options+ - hash of options, includes: execute_now,
  #    num_par_proces (max parallel processes), 
  #    target_type (servers/groups),
  #    job_name - to override the default job name,
  #    group_path - to override the default group path,
  #    version - to override use of component version
  #
  # ==== Returns
  #
  # * hash of job results, includes - job_run_id, job_status
  def create_nsh_script_job(script_name, script_group, job_params, options = {})
    result = {"status" => "ERROR"}
    job_type = "NSHScriptJob"
    version = get_option(options,"version", get_param("SS_component_version"))
    targets = get_option(options, "servers")
    if targets == ""
      servers = get_server_list 
      targets = server_dns_names(servers)
    end
    script_group = "/#{script_group}" unless script_group.start_with?("/")
    num_par_procs = get_option(options,"num_par_procs", 50)
    execute_now = get_option(options,"execute_now", false)
    target_type = get_option(options,"target_type", "servers")
    job_name = get_option(options, "job_name", default_item_name)
    group_path = get_option(options, "group_path", default_group_path(version, true))
    log "\tBuilding group path..."
    job_group_id = @baa.ensure_group_path(group_path, "Jobs")
    args = [
      group_path, #jobGroup
      job_name,  #jobName
      "Script job from automation", #description
      script_group,
      script_name,
      num_par_procs # number of parallel processes
      ]
    ss_job_key = @baa.execute_cli_command(job_type,"createNSHScriptJob",args)
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
    ss_job_key = @baa.execute_cli_command("Job", method_call,
            [
              ss_job_key,       #jobName
              servers     #comma separated list of groups
            ]) 
    raise "Command_Failed: cannot add targets: #{ss_job_key}" if ss_job_key.include?("ERROR")
    if execute_now
      param_result = @baa.set_nsh_script_params(job_name, group_path, job_params, false)
      raise "Command_Failed: cannot set job parameters: #{param_result}" if param_result.include?("ERROR")
      execute_result = @baa.execute_job_with_results(param_result["job_db_key"], result)
      raise "Command_Failed: cannot execute job: #{execute_result.inspect}" if execute_result["status"].include?("ERROR")
    end
    result["job_db_key"] = ss_job_key
    result["status"] = "SUCCESS"
    result
  end
  
  # Wrapper to run a shell action
  # opens passed script path, or executes passed text
  # processes the script in erb first to allow param substitution
  # note script may have keyword directives (see additional docs) 
  # uses BAA_FRAMEWORK_NSH_SCRIPT to locate the nsh_script
  # ==== Attributes
  #
  # * +script_file+ - the path to the script or the text of the script
  # * +options+ - hash of options, includes: 
  #    servers - to override step servers
  #    version - to override use of component version
  #    nsh_script_name - name of nsh_script to call
  #    nsh_script_group - group path of nsh script
  # ==== Returns
  #
  # action output
  #
  def execute_script(script_file, options = {})
    # get the body of the action
    content = File.open(script_file).read
    seed_servers = get_option(options, "servers")
    transfer_properties = get_option(options, "transfer_properties",{})
    nsh_script_group = get_option(options, "nsh_script_group")
    nsh_script_name = get_option(options, "nsh_script_name")
    version = get_option(options,"version", get_param("SS_component_version"))
    group_path = get_option(options, "group_path", default_group_path(version, true))
    job_name = get_option(options, "job_name", default_item_name)
    if nsh_script_name == "" && defined?(BAA_FRAMEWORK_NSH_SCRIPT)
      log "Using BAA_FRAMEWORK_NSH_SCRIPT defined in customer_include"
      nsh_script_group = File.dirname(BAA_FRAMEWORK_NSH_SCRIPT)
      nsh_script_name = File.basename(BAA_FRAMEWORK_NSH_SCRIPT)
    else
      raise "Command_Failed: BAA_FRAMEWORK_NSH_SCRIPT must be defined in customer_include.rb"
    end    
    keyword_items = get_keyword_items(content)
    log "\tBuilding group path..."
    job_group_id = @baa.ensure_group_path(group_path, "Jobs")
    params_filter = keyword_items.has_key?("RPM_PARAMS_FILTER") ? keyword_items["RPM_PARAMS_FILTER"] : DEFAULT_PARAMS_FILTER
    transfer_properties.merge!(get_transfer_properties(params_filter, strip_prefix = true))
    log "#----------- Executing Script on Remote Hosts -----------------#"
    log "# Script: #{script_file}"
    result = "No servers to execute on"
    # Loop through the platforms
    OS_PLATFORMS.each do |os, os_details|
      servers = get_platform_servers(os) if seed_servers == ""
      servers = get_platform_servers(os, seed_servers) if seed_servers != ""
      message_box "OS Platform: #{os_details["name"]}"
      log "No servers selected for: #{os_details["name"]}" if servers.size == 0
      next if servers.size == 0
      log "# #{os_details["name"]} - Targets: #{servers.inspect}"
      log "# Setting Properties:"
      add_channel_properties(transfer_properties, servers, os)
      brpd_compatibility(transfer_properties)
      transfer_properties.each{|k,v| log "\t#{k} => #{v}" }
      shebang = read_shebang(os, content)
      log "Shebang: #{shebang.inspect}"
      wrapper_path = build_wrapper_script(os, shebang, transfer_properties, {"script_target" => File.basename(script_file)})
      log "# Wrapper: #{wrapper_path}"
      target_path = @baa.nsh_path(transfer_properties["RPM_CHANNEL_ROOT"])
      log "# Copying script to target: "
      clean_line_breaks(os, script_file, content)
      files_to_deploy = ["//#{BAA_RPM_HOSTNAME}#{script_file}", "//#{BAA_RPM_HOSTNAME}#{wrapper_path}"]
      result = @baa.create_file_deploy_job(job_name, group_path, files_to_deploy, target_path, server_dns_names(servers), {"execute_now" => true})
      result.each{|k,v| log("#{k}: #{v}") }
      log "# Executing script on target via wrapper:"
      job_params = [@params["SS_application"], 
        @params["SS_component"], 
        @params["SS_environment"], 
        @params["SS_component_version"],
        @params["request_id"],
        target_path,
        File.basename(wrapper_path)
        ]
      result = create_nsh_script_job(nsh_script_name, nsh_script_group, job_params, {"servers" => server_dns_names(servers), "execute_now" => true})
      result.each{|k,v| log("#{k}: #{v}") }
    end
    result
  end
  
  # Creates a group path for BAA storage
  # optionally uses BAA_BASE_GROUP from customer_include, otherwise "BRPM"
  #
  # ==== Attributes
  #
  # * +version+ - version name
  # * +deploy+ - true if path is for deploy and hence needs environment tag
  #
  # ==== Returns
  #
  # * group_path string
  def default_group_path(version = nil, deploy = false)
    base_grp = defined?(BAA_BASE_GROUP) ? BAA_BASE_GROUP : "BRPM"
    version = precision_timestamp if version.nil? || version == ""
    result = "/#{base_grp}/#{get_param("SS_application")}/#{version}/#{get_param("SS_component")}"
    result.gsub!(version,"#{version}/#{get_param("SS_environment")}") if deploy
    result
  end
  
  # Creates a unique item name for BAA storage
  #
  # ==== Attributes
  #
  # * +version+ - version name
  #
  # ==== Returns
  #
  # * item name string
  def default_item_name(version = nil)
    version = precision_timestamp if version.nil? || version == ""
    "#{get_param("SS_component")}_nsh_#{get_param("request_id")}_#{version}"
  end

end

require "#{@params["SS_script_support_path"]}/baa_utilities"
@rpm.log "Initializing BAA transport"
baa_path = defined?(BAA_BASE_PATH) ? BAA_BASE_PATH : "/opt/bmc/blade8.5"
baa_url = defined?(SS_integration_dns) ? SS_integration_dns : "http://unknownBladelogicServerSetIntegration"
@baa = TransportBAA.new(baa_url, @params)
@baa.set_credential(SS_integration_dns, SS_integration_username, decrypt_string_with_prefix(SS_integration_password_enc), get_integration_details("role")) if defined?(SS_integration_dns)
@rpm.log "Path to BAA: #{BAA_BASE_PATH}"
@transport = DispatchBAA.new(@baa, @params)