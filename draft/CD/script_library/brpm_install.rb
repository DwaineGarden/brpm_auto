# Install BRPM after jenkins download on Windows server
#  Expecting these variable to be set
#  silent_install_path
#  brpm_path
#  RPM_artifact_name_<component>

os = "windows"
cur_server = @p.get_server_list.keys.first
staging_info = @p.get("instance_#{@p.SS_component}")
target_path = @p.required("target_path")
@rpm.log "# Unzipping package on target:"
wrapper_path = @transport.create_command_wrapper("unzip -o", os, staging_info["instance_path"], target_path)
result = @nsh.script_exec([cur_server], wrapper_path, target_path)
@rpm.log result
