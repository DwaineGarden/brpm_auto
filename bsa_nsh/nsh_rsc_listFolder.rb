require '/home/bbyrd/nsh_classy.rb'

@base_dir = "/Users/brady/Documents/dev_rpm/scripts"
@base_servers = ["ip-172-31-45-229.ec2.internal", "ip-172-31-36-115.ec2.internal"]

def log_it(it)
  log_path = "/Users/brady/Documents/dev_rpm/logs"
  #log_path = "/home/bbyrd/logs"
  txt = it.is_a?(String) ? it : it.inspect
  write_to txt
  return unless File.exist?(log_path)
  fil = File.open("#{log_path}/output_dir_#{@params["SS_run_key"]}", "a")
  fil.puts txt
  fil.close
end

def is_dir(nsh_path)
  res = @nsh.nsh_command("test -d #{nsh_path}; echo $?")
  res.split("\n")[2] == "0"
end

def execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  nsh_path = "/opt/bmc/blade8.5/NSH/bin"
  @nsh = NSH.new(nsh_path, script_params)
  
  begin
    if parent_id.blank?
      # root folder
      log_it "Setting root: #{@base_servers.inspect}"
      data = []
      @base_servers.each do |server|
        data << { :title => server, :key => "#{server}|//", :isFolder => true, :hasChild => true}
      end
      return data
    else
      log_it "Drilling in: #{parent_id}"
      dir = File.join(parent_id.split("|")[1],parent_id.split("|")[0])
      dir = "/#{dir}" if parent_id.split("|")[1] == "//"
      paths = @nsh.nsh_dir(dir).map{|k| [k,dir] }
      return [] if paths.nil?
      data = []
      paths.each do |path|
        is_folder = is_dir(File.join(path[1],path[0]))
        data << { :title => path[0], :key => "#{path[0]}|#{path[1]}", :isFolder => is_folder, :hasChild => is_folder}
      end
      log_it(data)
      data
    end
  rescue Exception => e
    log_it "#{e.message}\n#{e.backtrace}"
  end
end

def Not_execute(script_params, parent_id, offset, max_records)
  log_it "Starting Automation"
  begin
    if parent_id.blank?
      # root folder
      log_it "Setting root: #{@base_dir}"
      path = [File.basename(@base_dir),File.dirname(@base_dir)]
      return [{ :title => path[0], :key => "#{path[0]}|#{path[1]}", :isFolder => true, :hasChild => true, :hideCheckbox => true}] if path
      return []
    else
      log_it "Drilling in: #{parent_id}"
      dir = File.join(parent_id.split("|")[1],parent_id.split("|")[0])
      paths = Dir.entries(dir).reject{ |l| [".",".."].include?(l) }.map{|k| [k,dir] }
      return [] if paths.nil?
      data = []
      paths.each do |path|
        is_folder = !File.file?(File.join(path[1],path[0]))
        data << { :title => path[0], :key => "#{path[0]}|#{path[1]}", :isFolder => is_folder, :hasChild => is_folder}
      end
      log_it(data)
      data
    end
  rescue Exception => e
    log_it "#{e.message}\n#{e.backtrace}"
  end
end

def import_script_parameters
  { "render_as" => "Tree" }
end