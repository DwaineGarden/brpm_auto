# This dispatcher will be invoked to execute a Remote file put via nsh.
# The server list passed to this script will all have the source files
# copied to the target path relative to SS_CHANNEL_ROOT
#  BJB - added support for default version_tag
#        and property to hold copied filename
###
# source host:
#   name: Source Hostname
#   type: in-text
#   position: A1:C1
# source path:
#   name: Source Path
#   type: in-text
#   position: A2:C2
# target path:
#   name: Target Path (Relative to CHANNEL_ROOT)
#   type: in-text
#   position: A3:C3
###

@DEFAULT_CHANNEL_ROOT = '/tmp'
@WINDOWS_CHANNEL_ROOT = '/C/windows/temp'
@NUM_THREADS = 10 # degree of parallelism for this dispatcher
@NSH_OPTIONS = {
    nsh_path: '', # set to NSH dir path if nsh commands are not in PATH
    nshrunner: false, # set to true if you want to use nshrunner
    verbose: true,
    test_mode: false
}

@target_path_key = 'target path'
@source_path_key = 'source path'
@source_host_key = 'source host'
target_path = params[@target_path_key]
source_path = params[@source_path_key]
prop_name = "SS_dispatch_file_name"

if source_path.empty?
  if params.has_key?("step_version_artifact_url") && !params["step_version_artifact_url"].empty?
    write_to "Source path not specified, assuming VersionTag artifact path"
    source_path = params["step_version_artifact_url"]
    params[@source_path_key] = source_path
  else
    puts_stderr 'Source path not specified'
    exit 1
  end
end
@file_name = File.basename(source_path)

if target_path.empty?
  write_to "Target path not specified, assuming SS_CHANNEL_ROOT"
  params[@target_path_key] = '.'
else
  params[@target_path_key] = File.join(target_path, @file_name) if File.extname(target_path) == ""
end

if !params.has_key?(@source_host_key) || params[@source_host_key].empty?
  write_to "Source host not specified, assuming localhost"
  params[@source_host_key] = 'localhost'
end

write_to "Dispatch File Put for NSH\n"
write_to "Copying //#{params[@source_host_key]}#{params[@source_path_key]} to SS_CHANNEL_ROOT/#{params[@target_path_key]}"
write_to "On the following hosts: #{get_selected_hosts.inspect}\n"

@nsh_run = NshDispatchScript.new(params, @NSH_OPTIONS)

def params_to_env(params)
  params.each do |name, value|
    val = value.gsub("\n","_CR_").gsub("\r\n", "_CR_")
    ENV[name] = val
  end
end

if @nsh_run.bulk_copy?
  bulk_remote_path = ''
  server_list = []
  first_server_props = nil
  get_server_list(params).each do |server, props|
    first_server_props ||= props
    server_params = params.merge(props)
    params_to_env(server_params)
    target_path = get_target_path(server_params)
    if bulk_remote_path.empty? && !target_path.nil?
      # Get the first available target_path and use for remote path
      bulk_remote_path = "#{target_path}/#{params[@target_path_key]}".gsub(/\/\/*/,'/')
    end
    server_list << server_addr(server, props)
  end

  @nsh_run.log_tag_list = server_list
  @nsh_run.set_nsh_blcred(first_server_props)
  @nsh_run.ncp(server_list,"//#{params[@source_host_key]}/#{params[@source_path_key].gsub(/^\//,'')}", bulk_remote_path, @NUM_THREADS.to_i > 0 ? @NUM_THREADS.to_i : 1)
else
  get_server_list(params).each do |server, props|
    @nsh_run.log_tag_list = [server_addr(server, props)]
    @nsh_run.set_nsh_blcred(props)
    server_params = params.merge(props)
    params_to_env(server_params)
    target_path = get_target_path(server_params)
    remote_path = "#{target_path}/#{params[@target_path_key]}".gsub(/\/\/*/,'/')
    @nsh_run.ncp([server_addr(server, props)], "//#{params[@source_host_key]}/#{params[@source_path_key].gsub(/^\//,'')}", remote_path)
  end
end

# Force a property to hold the deployed filename
write_to "$$SS_Set_property{#{prop_name}=>#{@file_name}}$$\n"