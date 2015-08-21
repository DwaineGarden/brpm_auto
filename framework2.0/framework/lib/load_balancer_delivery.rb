# Load Balancer Delivery
#  Bradford Byrd ©BMC Software
#
# This class provides support for grouping targets together for processing.
# Typically, a group of targets are removed from a load balancer pool, modified and then added back into the pool
# This provides a "zero downtime" method of deployment
# To provide abstraction, you pass a reference and method name for the module that actually holds the load_balancer specific automation
# This module method will be passed an action (add or remove) and an array of targets
# Invoke this class in block fashion to process each load balancer group

class LoadBalancerDelivery
  # Initialize the class
  # ==== Attributes
  #
  # * +servers+ - the array of servers to process
  # * +processing_method+ - the style of processing "by_number" or "by_smartgroup" 
  # * +pattern+ - If using by_number processing, {"num_groups" => 6} for smartgroups, send ""  
  # * +module_ref+ - A reference to the module that holds the way to interact with the load balancer
  # * +module_method+ - The name of the method to call in the module_ref to execute add and remove commands
  #
  def initialize(servers,method,pattern,module_ref,module_method)
    @servers = servers
    @method = processing_method
    @pattern = pattern
    @module_ref = module_ref
    @automation = module_method
    @num_groups = 0
    @num_groups = @pattern["num_groups"] if @method == "by_number"
  end
  
  # In block form returns successive groups of targets for processing
  # Performs a load_balancer remove before returning the servers
  # Performs an add after server processing is complete
  # ==== Returns
  #
  # an array of servers
  #
  def load_balancer_grouping
    @group_num = 0
    load_balancer_server_groups.each do |target_info|
      @module_ref.send @automation.to_sym, "remove", target_info
      yield(target_info)
      @module_ref.send @automation.to_sym, "add", target_info
      @group_num += 1
    end
  end
  
  # Groups the target for sequential processing
  # Processes servers based on the method that the class was initialized with
  #
  # ==== Returns
  #
  # an array of arrays of server targets
  #
  def load_balancer_server_groups
    if @method.downcase == "by_smartgroup"
      return_val = [@servers]
    elsif @method == "by_number"
      num_servers = (@servers.size/@num_groups).to_i
      start_point = num_servers * @group_num
      return_val = []
      @num_groups.to_i.times do |k|
        if @servers[start_point..-1].size > num_servers
          return_val << @servers[start_point..(start_point + num_servers)]
        else
          return_val << @servers[start_point..-1]
        end
        start_point += (num_servers + 1)
      end
    end
    return_val
  end
    
end