# dispatch_srun.rb
#  Module for action dispatch with nsh protocol
libDir = File.expand_path(File.dirname(__FILE__))
require "#{libDir}/dispatch"


class SSHDispatcher < AbstractDispatcher
  # Initialize the class
  #
  # ==== Attributes
  #
  # * +nsh_object+ - handle to an NSH object
  # * +options+ - hash of options to use, send "output_file" to point to the logging file
  # * +test_mode+ - true/false to simulate commands instead of running them
  #
  def initialize(ssh_object, params, options = {})
    @ssh = SSHTransport.new([], @params, options)
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
      target_path = transfer_properties["RPM_CHANNEL_ROOT"]
      log "# Copying script to target: "
      clean_line_breaks(os, script_file, content)
      @ssh.set_servers(servers.keys)
      result = @ssh.copy_files([script_file], target_path)
      log @ssh.display_result(result)
      log "# Executing script on target via wrapper:"
      result = @ssh.script_exec(wrapper_path, target_path)
      log @ssh.display_result(result)
    end
    result
  end
  
  # Copies remote files to a local staging repository
  # 
  # ==== Attributes
  #
  # * +file_list+ - array of nsh-style paths (//server/path)
  # * +options+ - hash of options includes: source_server
  # ==== Returns
  #
  # hash of instance_path and md5 - {"instance_path" => "", "md5" => ""}
  #
  def package_artifacts(file_list, options = {})
    version = get_option(options, "version", "")
    version = "#{get_param("SS_request_number")}_#{precision_timestamp}" if version == ""
    staging_path = get_staging_dir(version, true)
    message_box "Copying Files to Staging via SSH"
    ans = @ssh.split_nsh_path(file_list.first)
    raise "Command_Failed: staging/build server not found, use nsh-style paths" if ans[0].length < 2
    @ssh.set_servers(ans[0])
    log "\t StagingPath: #{staging_path}"
    file_list.each do |file_path|
      log "\t #{file_path}"
      result = @ssh.download_files(file_path, staging_path)
      log "\tCopy Result: #{@ssh.display_result(result)}"
    end
    package_staged_artifacts(staging_path, version)
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
    message_box "Deploying Files to Targets via SSH"
    raise "Command_Failed: no artifacts staged in #{File.dirname(instance_path)}" if Dir.entries(File.dirname(instance_path)).size < 3
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
      target_path = servers.first[1].has_key?("CHANNEL_ROOT") ? servers.first[1]["CHANNEL_ROOT"] : os_details["tmp_dir"] if target_path == ""
      log "# Deploying package on target:"
      @ssh.set_servers(servers.keys)
      result = @ssh.copy_files(instance_path, target_path)
      log @ssh.display_result(result)
      log "# Unzipping package on target:"
      wrapper_path = create_command_wrapper("unzip -o", os, instance_path, target_path)
      result = @ssh.script_exec(wrapper_path, target_path)
      log @ssh.display_result(result)
    end
    @ssh.display_result(result)
  end
      
end

@rpm.log "Initializing ssh transport"
debug = defined?(@debug) ? @debug : false
options = {"debug" => debug}
@transport = SSHDispatcher.new(cap_ssh, @params, options)
