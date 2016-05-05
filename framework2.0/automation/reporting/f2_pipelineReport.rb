#---------------------- f2_pipelineReport.rb -----------------------#
# Description: Builds request/plan/version information into a datafile
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 

#---------------------- Arguments --------------------------#

###
# Report Title:
#   name: Optional
#   type: in-text
#   position: A1:F1
# Report Period:
#   name: Optional if working from release plan
#   type: in-list-single
#   list_pairs: none,none|10,last_10_days|20,last_20_days|30,last_30_days|60,last_60_days|90,last_90_days
#   position: A2:C2
# Request States:
#   name: States to include in report
#   type: in-list-multi
#   list_pairs: complete,complete|cancelled,cancelled|problem,problem|hold,hold
#   position: A3:C3
# Release Plan:
#   name: Optional - choose a release plan
#   type: in-external-multi-select
#   position: A4:D4
#   external_resource: f2_rsc_pipelineReportPlans
# Choose Applications:
#   name: Optional - default is all applications in plan/period
#   type: in-external-multi-select
#   position: A5:D5
#   external_resource: f2_rsc_pipelineReportApplications
# Report Data Status:
#   name: Optional
#   type: in-external-single-select
#   external_resource: f2_rsc_pipelineDataStatus
#   position: A6:F6
# Generate Plan Data:
#   name: Build Plan Data
#   type: in-list-single
#   list_pairs: no,no|yes,yes
#   position: A7:C7
# Report Data Info:
#   name: Data Generation
#   type: in-external-single-select
#   position: A8:F8
#   external_resource: f2_rsc_pipelineDataGenerator
# Report Data:
#   name: path to data file
#   type: out-file
#   position: A1:F1
# HTML Report:
#   name: path to report file
#   type: out-url
#   position: A2:F2
# Report Export Data:
#   name: path to report file
#   type: out-file
#   position: A3:F3
###

#---------------------- Declarations -----------------------#
require 'erb'
require 'csv'
require "#{FRAMEWORK_DIR}/brpm_framework.rb"
params["direct_execute"] = true #Set for local execution

#---------------------- Methods ----------------------------#
def report_file
  File.join(@params["SS_output_dir"], "report_data.json")
end

#---------------------- Variables --------------------------#
version = "1.0.0.1"
app_name = "Example"
template = File.join(File.dirname(FRAMEWORK_DIR),"automation","reporting","pipeline_report_template.html.erb")
report_title = @p.get("Report Title")

#---------------------- Main Body --------------------------#
@rpm.message_box "Building Report", "title"
@content = JSON.parse(File.read(report_file))
@content["title"] = report_title
template_content = File.read(template)
html_report = ERB.new(template_content).result(binding)
File.open(report_file.gsub("report_data.json","report.html"),"w+") do |f| 
  f.puts html_report
end
File.open(report_file.gsub("report_data.json","report.csv"),"w+") do |f|
  f.puts @content["columns"].to_csv
  @content["data"].each{|l| f.puts l.to_csv }
end
pack_response("Report Export Data", report_file.gsub("report_data.json","report.csv"))
pack_response("Report Data", report_file)
html_report_file = report_file.gsub("report_data.json","report.html")
ipos = html_report_file.index("automation_results/")
out_link = "#{@p.SS_base_url}/#{html_report_file[ipos..255]}"
pack_response("HTML Report", out_link)
