def perform_queries
    @content["templates"] = {}
    @content["applications"].each do |app_id|
      templates = templates_by_popularity_for_user_and_app(User.current_user, app_id)
      limit = 10
      @content["templates"][app_id] = templates[0..limit].map{|l| [l.id, l.name, l.rank] }
    end
    request_query = Request.select("requests.id, requests.name, environment_id, owner_id, plan_member_id, started_at, completed_at, aasm_state, origin_request_template_id")
    clauses = []
    clauses << "origin_request_template_id IN (#{@content["templates"].values.map{|l| l.map{|k| k[0] }}.flatten.join(",")})"
    request_query = request_query.joins('INNER JOIN apps_requests ON apps_requests.request_id  = requests.id')
    if @content["release_plans"] != "" && @content["release_plans"] != "null"
      clauses << "plan_members.plan_id IN (#{@content["release_plans"].join(",")})"
      request_query = request_query.joins('INNER JOIN plan_members ON plan_members.id  = requests.plan_member_id')
    end
    clauses << "started_at > '#{(Time.now - (86400 * @content["period"].to_i)).strftime("%Y-%m-%d")}'" if @content["period"].to_i > 0
    clauses << "aasm_state IN (#{@content["states"].map{|l| "'#{l}'" }.join(",")})"
    requests = request_query.functional.where(clauses.join(" AND "))
    log_it "Requests query: #{clauses.join(" AND ")}"
    return default_table([["1","none","No requests available with criteria"]]) if requests.size < 1
    steps = Step.select("id, name, aasm_state, work_started_at, work_started_at, owner_id, owner_type, version_tag_id, component_id").where("request_id in (#{requests.map(&:id).join(",")})").order("request_id, position")
    {"requests" => requests, "steps" => steps}
end


states = ["complete", "problem", "hold"]
totals = {}
@content["templates"].each do |template_id|
  totals[template_id] = {}
  env_result = Request.joins(:environment).select("distinct(environments.name)").functional.where("origin_request_template_id = 49")
  env_result.map(&:name).each do |env|
    puts "#------ #{env} -------------#"
    totals[template_id][env] = {}
    @content["states"].each do |state|
      res = Request.joins(:environment).functional.where("origin_request_template_id = #{template_id} AND environments.name = '#{env}' AND aasm_state = '#{state}'").count
      puts "State: #{state} => #{res}"
      totals[template_id][env][state] = res
    end
  end 
end    