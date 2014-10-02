#---------------------- nsh_script_execute -----------------------#
# Description: Executes a script on another host
#   script may be another rpm script or on file system

#---------------------- Arguments --------------------------#
###
#  Script to Execute:
#   name: name (in BRPM) or nsh-path to script to execute
#   type: in-text
#   position: A1:F1
#   required: yes
#  Target Directory:
#   name: Path on target server to run from
#   type: in-text
#   position: A2:F2
#   required: no
###

#---------------------- Declarations -----------------------#
require 'erb'
params["direct_execute"] = true #Set for local execution
include_property = "include_path_ruby"
if params.has_key?(include_property)
  tmp = params[include_property]
  if File.exist?(tmp)
    require tmp
  else
  	write_to("Command_Failed: cant find include file: " + tmp)
  end
else
  write_to "This script requires a property: #{include_property}"
  #exit(1)
end
# Initialize an nsh class
@nsh = NSH.new("/opt/bmc/blade8.5/NSH")
# Set an active record connection to BRPM
db_info = init_brpm_db_connection
# Declare a class wrapper for the db table
class Script < ActiveRecord::Base
end

#---------------------- Methods ----------------------------#
# Assign local variables to properties and script arguments
def script_contents(script_name)
  start_s = "#---------START_SHELL_SCRIPT----------#"
  end_s = "#--------END_SHELL_SCRIPT-------------#"
  reg = /#{start_s}.*#{end_s}/m
  script_record = Script.find_by_name(script_name)
  if script_record.nil?
    write_to "Command_Failed: Cannot find Automation by name: #{script_name}"
    exit(1)
  end
  res = script_record.content.scan(reg)
  if res.empty?
    write_to "Command_Failed: Shell script does not have proper start and ends"
    exit(1)
  end
  script = res[0].gsub(start_s,"").gsub(end_s,"")
  script
end

#---------------------- Variables --------------------------#
# Assign local variables to properties and script arguments
server_list = get_server_list(@params)
hosts = server_list.map{ |srv| srv[0] }

script_name = @p.get("Script to Execute")
target_dir = @p.get("Target Directory","/tmp")

#---------------------- Main Body --------------------------#
message_box "Running remote script", "title"
write_to "\tScript: #{script_name}\n\t On hosts: #{hosts.join(",")}\n"

# Could be sending an nsh path to the script
if script_name =~ /(\/|\\)/
  @nsh.ncp("localhost", script_name, "/tmp")
  full_path = "/tmp/#{File.basename(script_name)}#{File.extname(script_name)}"
else
# or a script name in BRPM
  script = script_contents(script_name)
  write_to "#--------- Running -----------#\n#{script}\n#------ END ---------#"
  script_file = "nsh_script_#{@timestamp}.sh"
  full_path = "#{@p.SS_output_dir}/#{script_file}"
  file_contents = ERB.new(script).result(binding)
  fil = File.open(full_path,"w+")
  fil.write file_contents.gsub("\r", "")
  fil.flush
  fil.close
end

begin
  result = @nsh.script_exec(hosts, full_path, target_dir)
  message_box("Script Results")
  write_to result
rescue Exception => e
  write_to "Command_Failed: #{e.message}\n#{e.backtrace}"
end


