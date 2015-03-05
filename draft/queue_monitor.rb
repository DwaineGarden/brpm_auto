#!/usr/bin/env jruby
require 'rubygems'
require 'torquebox'
require 'torquebox-messaging'
require 'xmlsimple'

class Logger
  @params = {}

  def self.initialize(params)
    @params = params
  end

  def self.get_request_log_file_path
    "#{@params["SS_automation_results_dir"]}/#{@params["request_id"]}.log"
  end

  def self.get_step_run_log_file_path
    "#{@params["SS_automation_results_dir"]}/#{@params["request_id"]}_#{@params["step_id"]}_#{@params["SS_run_key"]}.log"
  end

  def self.log(message)
    message = message.to_s # in case booleans or whatever are passed
    timestamp = "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"
    log_message = ""

    if @params["log_file"]
      prefix = "#{timestamp}|"
      message.gsub!("\n", "\n" + (" " * prefix.length))

      log_message = "#{prefix}#{message}\n"

      File.open(@params["log_file"], "a") do |log_file|
        log_file.print(log_message)
      end
    else
      prefix = "#{timestamp}|#{'%2.2s' % @params["step_number"]}|#{'%-20.20s' % @params["step_name"]}|"
      message.gsub!("\n", "\n" + (" " * prefix.length))

      log_message = "#{prefix}#{message}\n"

      File.open(self.get_request_log_file_path, "a") do |log_file|
        log_file.print(log_message)
      end

      File.open(self.get_step_run_log_file_path, "a") do |log_file|
        log_file.print(log_message)
      end
    end

    print(log_message) if @params.has_key?("local_debug") && @params["local_debug"]=='true'
  end

  def self.log_error(message)
    self.log ""
    self.log "******** ERROR ********"
    self.log "An error has occurred"
    self.log "#{message}"
    self.log "***********************"
    self.log ""
  end
end

Logger.initialize({ "log_file" => ENV["EVENT_HANDLER_LOG_FILE"] })

port = ENV["EVENT_HANDLER_MESSAGING_PORT"]
username = ENV["EVENT_HANDLER_MESSAGING_USERNAME"]
password = ENV["EVENT_HANDLER_MESSAGING_PASSWORD"]
process_event_script = ENV["EVENT_HANDLER_PROCESS_EVENT_SCRIPT"]

require "#{process_event_script}"

class MessagingProcessor < TorqueBox::Messaging::MessageProcessor

  MESSAGING_PATH = '/topics/messaging/brpm_event_queue'

  def initialize(port, username, password)
    Logger.log "Initializing the message processor..."
    @destination = TorqueBox::Messaging::Topic.new(
        MESSAGING_PATH,
        :host => 'localhost',
        :port => port,
        :username => username,
        :password => password
    )
  end

  def run
    begin
      event = XmlSimple.xml_in("<root>#{@destination.receive}</root>")

      Logger.log event.inspect if ENV["EVENT_HANDLER_LOG_EVENT"]=="1"

      Logger.log "Processing new event..."
      process_event(event)

    rescue Exception => e
      Logger.log_error(e)
      Logger.log e.backtrace.join("\n\t")
    end
  end
end

begin
  consumer = MessagingProcessor.new(port, username, password)
  Logger.log "Starting to listen for events ..."
  puts "#------------------------------------------------------------#"
  puts "#      Monitoring RPM-HornetQ on port: #{port}"
  puts "#------------------------------------------------------------#"
  
  loop do
    consumer.run
  end

rescue Exception => e
  Logger.log_error(e)
  Logger.log e.backtrace.join("\n\t")

  raise e
end
