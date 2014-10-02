class VersionTag < BrpmRest
  
  def initialize(url, options = {})
    super(url, options)
  end
# Takes an array of version tag info and creates the version tags
#
# ==== Attributes
#
# * +tag_info+ - an array of hashes
# ex: [{ "application" => "app1", "component" => "database", "name" => "1.2.1", "artifact_url" => "file:///home/brady/stuff"}]
#
# ==== Returns
#
# * a hash of the command output
def create_version_tags(tag_info, options = {})
  # Meant to be called after importing a spreadsheet of versions
  results = {"status" => "ERROR", "message" => "", "data" => []}
  message = "Processing tags: #{tag_info.size.to_s} to do\n"
  version_tag = { "name" => "", "artifact_url" => "", "find_application" => "", "find_component" => "", "active" => true}
  tag_info.each do |v_tag|
    if v_tag.has_key?("name")
      version_tag["find_application"] = v_tag["application"]
      version_tag["find_component"] = v_tag["component"]
      version_tag["name"] = v_tag["name"]
      version_tag["artifact_url"] = v_tag["artifact_url"]
      message += "adding #{v_tag["name"]} to #{v_tag["component"]}"
      result = create("version_tags", {"version_tag" => version_tag}, options)
      message += ", Status: #{result["status"]}\n"
      results["data"] << result["data"]
      results["status"] = result["status"]
    else
      message += "bad record: #{v_tag.inspect}\n"
    end
  end
  results["message"] = message
  results
end

# Queries RPM for a version by name
#
# ==== Attributes
#
# * +name+ - a version name
#
# ==== Returns
#
# * an array of matching version objects or "ERROR" if not found
#
def version_tag_query(name)
  result = "ERROR"
  result = get("version_tags",nil,{"filters" => "filters[name]=#{url_encode(name)}"})
  if result["status"] == "success"
    log "Tag Exists?: #{@base_url}\nResult: #{result["data"].inspect}"
    result = result["data"]
  end
  result
end

# Takes a version name and assigns it to the steps in a request
# === skips steps where the version does not exist
# ==== Attributes
#
# * +version+ - name of a version
# * +steps+ - an array of steps (returned from rest call to requests)
# * +options+ - hash of options passed to rest object e.g. {"verbose" => "yes"}
#
# ==== Returns
#
# * success or ERROR
#
def assign_version_to_steps(version, steps, options = {})
  result = "ERROR - failed to update steps"
  components = steps.map{|l| l["component_name"]}.uniq
  version_tags = version_tag_query(version)
  return "ERROR no version tags for #{version}" if version_tags.is_a?(String) && version_tags.start_with?("ERROR")
  components.reject{|l| l.nil? }.each do |component|
    comp_steps = steps_with_matching_component(steps, component)
    version_tag_id = "0"
    version_tags.each{|k| version_tag_id = k["id"] if k["installed_component_id"] == comp_steps[0]["installed_component_id"] }
    if version_tag_id == "0"
      log "No version_tag for component: #{component}"
    else
      comp_steps.each do |step|      
        step_data = {"version_tag_id" => version_tag_id, "component_version" => version}
        rest_result = update("steps", step["id"], step_data, options)
        if rest_result["status"] == "success"
          log "Updating step: #{step["id"]}\nResult: #{rest_result["data"].inspect}"
          result = "success"
        end
      end
    end
  end
  result
end

# Takes an array of step objects and a component and returns the steps that match
#
# ==== Attributes
#
# * +steps+ - an array of steps (returned from rest call to requests)
# * +comp+ - a component name
#
# ==== Returns
#
# * array of the steps that match
def steps_with_matching_component(steps, comp)
  result = []
  steps.each do |step|
    result << step if !step["installed_component_id"].nil? && comp == step["component_name"]
  end
  result
end
end