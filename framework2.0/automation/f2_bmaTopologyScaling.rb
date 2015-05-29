# Description: Utility to read a Server Profile for JVM count and clone BMA server config package to the count
# Description: Manipulate XML in BMA config files
# actions = append| clone| replace
###
# Topology Item:
#   name: Choose an item to scale using the server profile tokens
#   type: in-list-single
#   list_pairs: serverclones,serverclones|virtualhosts,virtualhosts
#   position: A1:C1
# Server Profile Path:
#   name: enter name/path of server profile
#   type: in-text
#   position: A2:F2
# Config Package Path:
#   name: enter name/path to config package on BMA server
#   type: in-text
#   position: A3:F3
###
#--------------------------- Declarations ---------------------------------#
require 'nokogiri'
require 'fileutils'
params["direct_execute"] = true #Set for local execution

#----------------------------- Methods -----------------------------------#
def find_and_replace(file, output_path, find_replace_hash, output_name)
	text = File.read(file)
	find_replace_hash.each do |k,v|
		@rpm.log "find = #{k}, replace = #{v}" if @debug
		text.gsub!(/#{k}/,v)
	end	
	File.open("#{output_path}/#{output_name}.xml", "w") {|file| file.puts text}
end

def find_in_children(find_attr, find_value)
    found.first.children.each do |child|
      @rpm.log child.name
      new_node = child.dup if child[find_attr] == find_value
    end
end
		
def clone_and_attribute(nodeset,attrs)
  new_node = nodeset.first.dup
  attrs.each do |k,v|
    new_node[k] = v if new_node[k]
  end
  new_node
end

#---------------------------- Variables -----------------------------------#
@debug = false
bma_mod_type = @p.required("Topology Item")
environment_name = @p.get("HHSC_ENV", @p.SS_environment)
app_name = @p.get("HHSC_APP", @p.SS_application)
bma_action = "topology"
@timestamp = Time.now.strftime("%Y%m%d%H%M%S")
bma_details(bma_action) #creates the @bma hash referred to in the shell automation erb
staging_dir = staging_path
classification_const = "classNameForSub"
tokenset_name = @p.get("HHSC_BMA_TOKEN_SET")
bma_working_dir = clearcase_view_path

bma_server_profile_path = server_profile_path(@p.get("Server Profile Path"))
bma_server_profile = File.basename(bma_server_profile_path)
bma_config_package_path = config_package_path(@p.get("Config Package Path"))
bma_config_package = File.basename(bma_config_package_path)
_d_mod = bma_config_package.include?("_d.xml") ? "_d" : ""

if bma_mod_type == "serverclone"
  action = "clone"
  n = 1
  clone_names = []
  clone_basename_token_key = "CLONES_BASE_NAME"
  classification_data_key = "SERVER_DISTRIB_NODE"
  clones_const = "nodeNameForSub"
  temp_config_file_path = "#{staging_dir}/mwconfig/server_tmp/processed"
  output_file =  "#{temp_config_file_path}/#{bma_server_profile}_#{bma_config_package}-serverModified#{_d_mod}.xml"
  
else # Virtual Hosts
  vhostname = "${ph:VHOST_NAME}"
  clone_basename_token_key = "VHOST_PORTS"
	temp_config_file_path = "#{staging_dir}/mwconfig/vhosts_tmp/processed"
  output_file = "#{temp_config_file_path}/#{bma_server_profile}_#{bma_config_package}-vhostModified.xml"	
end

#------------------------------- MAIN -------------------------------------#
@rpm.message_box "BMA Topology Modifications - #{bma_mod_type}", "title"
@rpm.log "Server Profile: #{bma_server_profile}\nConfig Package: #{bma_config_package}\nOutput to: #{temp_config_file_path}\nTokenSet Name: #{tokenset_name}\n"
@rpm.log "Tokenset: #{tokenset_name} | Scaling Token: #{token_name}"
@rpm.log "Output file: #{output_file}"

#Check if -server.xml exists in the staging location
unless File.exist?(bma_server_profile_path) && File.exist?(bma_config_package_path)
	@rpm.log "Command_Failed: Server profile or configuration file not found\n#{bma_server_profile_path}\n#{bma_config_package_path}"
	exit(1)
end	

@profile = Nokogiri::XML(File.open(bma_server_profile_path).read)
@config = Nokogiri::XML(File.open(bma_config_package_path).read)
#Make a copy of the appname-server.xml config package in the temp_config_file_path
FileUtils.cp(bma_config_package_path, temp_config_file_path)

if bma_mod_type == "serverclone" # Server Clones
  classification_data = @profile.xpath("//TokenSet[@Name='#{tokenset_name}']/Token[starts-with(@Key, '#{classification_data_key}')]")
  clone_basename_token = @profile.xpath("//TokenSet[@Name='#{tokenset_name}']/Token[@Key='#{clone_basename_token_key}']")
  clones_basename = clone_basename_token.first["Value"]
  if classification_data.empty? || clone_basename_token.empty? 
  	@rpm.log "Command_Failed: Unable to find the tokens #{classification_data_key} or #{clone_basename_token_key} in tokenset #{tokenset_name}"
  	exit(1)
  end
  classification_data.each do |rec|
  	node_name = rec["Value"].split(",")[0]
  	clones_id = rec["Value"].split(",")[1..-1]
  	clones_id.each do |id|
  		clone_name = clones_basename.to_s.strip + id.to_s
  		@rpm.log "Found clone name: #{clone_name} for node: #{node_name}"
  		clone_names << clone_name unless clone_name.length < 2
  		find_replace_hash = {clones_const => clone_name, classification_const => node_name}
  		@rpm.log "#{find_replace_hash.inspect}" if @debug
  		find_and_replace(bma_config_package_path, temp_config_file_path, find_replace_hash, clone_name)
  	end
  end
  @doc_master = Nokogiri::XML(File.open("#{temp_config_file_path}/#{clone_names.first}.xml").read)
  master_server = @doc_master.xpath("//Server[@name='#{clone_names.first}' and @serverType='APPLICATION_SERVER']")
  clone_names[1..-1].reverse.each do |clone_name|
  	@doc_source = Nokogiri::XML(File.open("#{temp_config_file_path}/#{clone_name}.xml").read)
  	source_server = @doc_source.xpath("//Server[@name='#{clone_name}' and @serverType='APPLICATION_SERVER']")
  	master_server.first.add_next_sibling(source_server)
  end
  ##
  fil = File.open(output_file, "w+")
  fil.write @doc_master
  fil.close
  @rpm.log "Temporary configuration package created: #{output_file}" if File.exist?(output_file)
  if @debug == false
  	@rpm.log "Removing temporary file: #{temp_config_file_path}/#{bma_config_package}-server.xml" if File.exist?("#{temp_config_file_path}/#{bma_config_package}-server.xml")
  	FileUtils.rm("#{temp_config_file_path}/#{bma_config_package}-server.xml") if File.exist?("#{temp_config_file_path}/#{bma_config_package}-server.xml")
  	clone_names.each do |clone_name|
  		@rpm.log "Removing temporary file: #{clone_name}"
  		FileUtils.rm("#{temp_config_file_path}/#{clone_name}.xml")
  	end
  end		
else # Virtual Host
  tokens = {}
  token = @profile.xpath("//TokenSet[@Name='#{tokenset_name}']/Token[@Key='#{clone_basename_token_key}']")
  #tokens = tokenset.xpath("//Token[contains(@Key, 'VHOST_')]") Key="VHOST_PORTS" Value="80,443,10039,10029"
  @rpm.log "Token is #{token} ..."

  if ( token.empty? )
    # When VHOST configuration does not exist copy the existing -res.xml to vhostModified.xml
  	@rpm.log "Empty token found - No vhosts merging required. Using the -res.xml from staging_dir #{staging_dir}"
  else
    @rpm.log "Token has a value : #{token}"
  	value = token.first["Value"]
  	ports = value.split(",") #into an array
  	@rpm.log "Ports found in TokenSet: #{ports}"
  	tmp = []
  	ports.each do |port|
  		port.strip!
  		port = port.to_i.to_s
  		tmp << {"port" => port}
  		tokens = {"virtual_host" => tmp}
  	end  

  	change_items = {
  	#   "clone_server" => {:xpath => "//JDBCProvider[@Target='stpClone2']", :action => :clone, :token_set => @sit_tokens},
  	#   "append_data_source" => {:xpath => "//DataSource[@authDataAlias='wpdsCUSU2JAASAuth']", :action => :append, :token_set => @sit_tokens},
  	#   "corba_bindings" => {:xpath => "//StringNameSpaceBinding[@name='CorbaLookupIdentier']", :action => :append, :key_name => "stringToBind", :token_set => @sit_tokens},
  	#   "virtual_host" => {:xpath => "//VirtualHost[@name='default_host']/HostAlias", :action => :clone, :key_name => "port", :token_set => @sit_tokens}
  	   "virtual_host" => {:xpath => "//VirtualHost[@name='#{vhostname}']/HostAlias", :action => :"#{action}", :key_name => "port", :token_set => tokens}
  	  }
  	change_items.each do |item, action_info|
  	  @rpm.log "#{divider}#---- Modifying item: #{item} - action = #{action_info[:action].to_s}"
  	  @rpm.log "\txpath: #{action_info[:xpath]}"
  	  found =  @config.xpath(action_info[:xpath])
  	  if found.size > 0
    		new_node = nil
    		@rpm.log "\t#{found.size} items found (doing only first)"
    		#Assume xpath is specific and just do the first item
    		if action_info[:action] == :clone
      		#change the first HostAlias element to the first value in the @tokens
      		found.first[action_info[:key_name]] = action_info[:token_set][item].first.values[0]
      		#now delete that from the token_set
      		action_info[:token_set][item].first.delete("port")
      		if action_info[:token_set][item] && action_info[:token_set][item].is_a?(Array)
      			action_info[:token_set][item].each do |cur_val|
      			  new_node = clone_and_attribute(found, cur_val) unless cur_val.empty?
      			  found.first.add_next_sibling(new_node) unless cur_val.empty?
      			  @rpm.log "New Clone: #{new_node["port"]}" if !new_node.nil?
      		  end
  		    elsif action_info[:token_set][item] && action_info[:token_set][item].is_a?(Hash)
  			    new_node = clone_and_attribute(found, action_info[:token_set][item])
  			    found.first.add_next_sibling(new_node)
  		    else
  			    new_node = clone_and_attribute(found, {action_info[:key_name] => action_info[:token_set][item]})
  			    found.first.add_next_sibling(new_node)
  		    end
  		  elsif action_info[:action] == :append
  		    found.first[action_info[:key_name]] = found.first[action_info[:key_name]] + action_info[:token_set][item.to_s]
  		  elsif action_info[:action] == :replace
  		    found.first[action_info[:key_name]] = action_info[:token_set][item.to_s]
  		  else
  			  @rpm.log "failed: Action not found"
  		  end
  		  @rpm.log "Processed: #{item}\n#{found.first.to_s}"
      else
  	    @rpm.log "\tfailed: Not Found #{action_info[:xpath]}"
      end
    end
  end
  
	fil = File.open(output_file, "w+")
	fil.write @config
	fil.close
	if File.exist?(output_file)
		@rpm.log "Temporary configuration package created: #{output_file}-res.xml"
	end	
end    
