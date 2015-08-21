#  Load Balancer Control Module for F5

module F5
  class << self
    def control_action(action,targets)
      if action == "add"
        puts "F5 - Adding targets: #{targets.join(",")}"
      else
        puts "F5 - Removing targets: #{targets.join(",")}"
      end
    end
  end
end
