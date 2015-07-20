def has_path(path)
  return false if path.nil?
  return true if path.include?("/")
  return true if path.include?("\\")
end

def transform_xml(file_path)
  xsl_template = "#{ACTION_LIBRARY_PATH}/BMA/report.xsl"
  xsl_doc = Nokogiri::XSLT(File.read(xsl_template))
  doc = Nokogiri::XML(File.read(file_path))
  result_file = File.join(@p.SS_output_dir,"bma_report_#{@timestamp}.html")
  result = xsl_doc.transform(doc)
  fil = File.open(result_file, "w+")
  fil.write result.to_html
  fil.close
  result_file
end

def clearcase_view_path
  env = @p.SS_environment
  lower_environments = ["DEV", "LOCAL", "AUTH", "SIT"]
  lower_env = false
  lower_environments.each{|k| lower_env = true if env.include?(k) }
  source_stream = @p.required("HHSC_SOURCE_STREAM")
  if lower_env
    view_path = "/eastage/views/MW_LW_CFG_#{source_stream}/mwlw/MWLWRelease"
  else
    view_path = "/eastage/views/MW_UP_CFG_#{source_stream}/mwup/MWUPRelease"
  end
  view_path
end

def staging_path
  # /portalstage/staging/SIT2B/PORTALFW/mwconfig/
  "#{@p.get("HHSC_ROOT_STAGE_DIR")}/staging/#{@p.get("HHSC_ENV", @p.SS_environment)}/#{@p.get("HHSC_APP", @p.SS_application)}/mwconfig"
end

def config_package_name(package_type = "resource")
  package_types = {
    "resource" => "res",
    "resource_delete" => "res_d",
    "app" => "app",
    "app_delete" => "app_d",
    "server" => "server",
    "server_delete" => "server_d",
  }
  "#{@p.get("HHSC_BMA_CONFIG_PACKAGE")}-#{package_types[package_type]}.xml"
end

def config_package_path(config_package_tmp = nil, package_type = "resource")
  config_package_tmp = @p.get("HHSC_BMA_CONFIG_PACKAGE") if config_package_tmp.nil? || config_package_tmp == ""
  if config_package_tmp == ""
    package_path = "#{staging_path}/#{config_package_name}"
  elsif has_path(config_package_tmp)
    package_path = config_package_tmp
  else
    package_path = "#{staging_path}/#{config_package_tmp}"
  end
  package_path
end

def server_profile_path(server_profile_tmp = nil)
  # /eastage/views/MW_UP_CFG_#{@params["HHSC_SOURCE_STREAM"]}/mwup/MWUPRelease/serverprofiles
  server_profile_tmp = @p.get("HHSC_BMA_SERVER_PROF") if server_profile_tmp.nil? || server_profile_tmp == "" # This will always be the serverModified.xml
  if server_profile_tmp == ""
    raise "ERROR: no server profile specified"
  elsif has_path(server_profile_tmp)
    profile_path = server_profile_tmp
  else
    profile_path = "#{clearcase_view_path}/serverprofiles/#{@p.get("HHSC_ENV", @p.SS_environment)}/#{server_profile_tmp}"
    #profile_path = "#{@rpm.get_integration_details["BMA_WORKING"]}/serverprofiles/#{@p.get("HHSC_ENV", @p.SS_environment)}/#{server_profile_tmp}"
  end
  profile_path
end

def bma_details(action = "snapshot", options = {})
  integration_details = @rpm.get_integration_details
  @bma = {
    "action" => action,
    "server_dns" => SS_integration_dns,
    "platform" => integration_details["BMA_PLATFORM"],
    "home_dir" => integration_details["BMA_HOME"],
    "license" => integration_details["BMA_LICENSE"],
    "working_dir" => @rpm.get_option(options, "working_dir", integration_details["BMA_WORKING"]),
    "properties" => @rpm.get_option(options, "properties", "#{integration_details["BMA_PROPERTIES"]}_#{@p.get("BMA_MIDDLEWARE_PLATFORM", "was85")}.properties"),
    "log_level" => "ERROR",
    "snapshots_dir" => "#{integration_details["BMA_WORKING"]}/snapshots",
    "archive_dir" => "#{integration_details["BMA_WORKING"]}/archive",
    "reports_dir" => "#{integration_details["BMA_WORKING"]}/reports",
    "staging_dir" => staging_path   
  }
end