# dispatch_srun.rb
#  Module for action dispatch with nsh protocol
libDir = File.expand_path(File.dirname(__FILE__))
require "#{libDir}/dispatch"


class NSHDispatcher < AbstractDispatcher
  # Initialize the class
  #
  # ==== Attributes
  #
  # * +nsh_object+ - handle to an NSH object
  # * +options+ - hash of options to use, send "output_file" to point to the logging file
  # * +test_mode+ - true/false to simulate commands instead of running them
  #
  def initialize(nsh_object, params, options = {})
    @nsh = nsh_object
    @verbose = get_option(options, "verbose", false)
    @params = params
    super(params)
    @output_dir = get_param("SS_output_dir")
  end
  
  # Wrapper to run a shell action
  # opens passed script path, or executes passed text
  # processes the script in erb first to allow param substitution
  # note script may have keyword directives (see additional docs) 
  # ==== Attributes
  #
  # * +script_file+ - the path to the script or the text of the script
  # * +options+ - hash of options, includes: servers to override step servers
  # ==== Returns
  #
  # action output
  #
  def execute_script(script_file, options = {})
    # get the body of the action
    content = File.open(script_file).read
    seed_servers = get_option(options, "servers")
    transfer_properties = get_option(options, "transfer_properties",{})
    keyword_items = get_keyword_items(content)
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
      target_path = nsh_path(transfer_properties["RPM_CHANNEL_ROOT"])
      log "# Copying script to target: "
      clean_line_breaks(os, script_file, content)
      result = @nsh.ncp(servers.keys, script_file, target_path)
      log result
      log "# Executing script on target via wrapper:"
      result = @nsh.script_exec(servers.keys, wrapper_path, target_path)
      log result
    end
    result
  end
  
  # Copies remote files to a local staging repository
  # 
  # ==== Attributes
  #
  # * +file_list+ - array of nsh_paths
  # * +version+ - path to nsh
  # ==== Returns
  #
  # hash of instance_path and md5 - {"instance_path" => "", "md5" => ""}
  #
  def package_artifacts(file_list, version = "")
    version = "#{get_param("SS_request_number")}_#{precision_timestamp}" if version == ""
    staging_path = get_staging_dir(version, true)
    message_box "Copying Files to Staging via NSH"
    log "\t StagingPath: #{staging_path}"
    file_list.each do |file_path|
      log "\t #{file_path}"
      result = @nsh.ncp(nil, nsh_path(file_path), staging_path)
      log "\tCopy Result: #{result}"
    end
    package_staged_artifacts(staging_path, version)
  end

  # Packages files from local staging directory
  # 
  # ==== Attributes
  #
  # * +staging_path+ - path to files
  # * +version+ - version to assign
  # ==== Returns
  #
  # hash of instance_path and md5 - {"instance_path" => "", "md5" => ""}
  def package_staged_artifacts(staging_path, version)
    package_file = "package_#{version}.zip"
    instance_path = File.join(staging_path, package_file)
    return {"instance_path" => "ERROR - no files in staging area", "md5" => ""} if Dir.entries(staging_path).size < 3
    cmd = "cd #{staging_path} && zip -r #{package_file} *"
    result = execute_shell(cmd)
    md5 = Digest::MD5.file(instance_path).hexdigest
    {"instance_path" => instance_path, "md5" => md5}
  end
  
  # Deploys a packaged instance based on staging info
  # staging info is generated by the stage_files routine
  # ==== Attributes
  #
  # * +staging_info+ - hash returned by stage_files 
  # * +options+ - hash of options, includes allow_md5_mismatch(true/false) and target_path to override server channel_root
  # ==== Returns
  #
  # action output
  #
  def deploy_package_instance(staging_info, options = {})
    mismatch_ok = get_option(options, "allow_md5_mismatch", false)
    target_path = get_option(options, "target_path")
    instance_path = staging_info["instance_path"]
    message_box "Deploying Files to Targets via NSH"
    log "\t StagingArchive: #{instance_path}"
    md5 = Digest::MD5.file(instance_path).hexdigest
    md5_match = md5 == staging_info["md5"]
    log "\t Checksum: expected: #{staging_info["md5"]} - actual: #{md5}#{md5_match ? " MATCHED" : " NO MATCH"}"
    raise "Command_Failed: bad md5 checksum match" if !md5_match && !allow_md5_mismatch
    result = "No servers to execute on"
    # Loop through the platforms
    OS_PLATFORMS.each do |os, os_details|
      servers = get_platform_servers(os)
      message_box "OS Platform: #{os_details["name"]}"
      log "No servers selected for: #{os_details["name"]}" if servers.size == 0
      next if servers.size == 0
      log "# #{os_details["name"]} - Targets: #{servers.inspect}"
      target_path = nsh_path(target_path) if target_path != ""
      target_path = nsh_path(servers.first[1].has_key?("CHANNEL_ROOT") ? servers.first[1]["CHANNEL_ROOT"] : os_details["tmp_dir"]) if target_path == ""
      log "# Deploying package on target:"
      result = @nsh.ncp(servers.keys, instance_path, target_path)
      log result
      log "# Unzipping package on target:"
      wrapper_path = create_command_wrapper("unzip -o", os, instance_path, target_path)
      result = @nsh.script_exec(servers.keys, wrapper_path, target_path)
      log result
    end
    result
  end
      
end
