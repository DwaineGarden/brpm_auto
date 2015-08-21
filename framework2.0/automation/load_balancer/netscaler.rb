#  Load Balancer Control Module for F5

module NetScaler
  class << self
    def control_action(action,targets)
      if action == "add"
        puts "Netscaler - Adding targets: #{targets.join(",")}"
      else
        puts "Netscaler - Removing targets: #{targets.join(",")}"
      end
    end
  end
end
