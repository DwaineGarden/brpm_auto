# brpm_auto

## Framework and Automations for BRPM

### The BRPM Framework is a collection of libraries to enhance the capability and experience of developing automation for BRPM.

To use the framework in your environment, follow these steps:

1. Get a GitHub account and send me you ssh key so I can get you repository access

2. Clone the repository to your computer

3. Create a couple of folders in your RLM base folder (/opt/bmc/RLM) to hold the framework
  * /opt/bmc/RLM/persist/automation_lib

4. Edit the customer_include.rb file with your constants and routines that you want globally available

5. Put a couple of lines in your brpm automation like this:  
  `#=> ------------- IMPORTANT ------------------- <=#`  
  `# This loads the BRPM Framework and sets: @p = Params, @auto = BrpmAutomation and @rest = BrpmRest`  
  `require @params["SS_automation_results_dir"].gsub("automation_results","persist/automation_lib/brpm_framework.rb")`  

6. Start using the framework!

7. RTFM - Take the docs.zip file and expand it somewhere on your machine, then point your browser to the index.html file in the doc folder

8. Look at the example automation (f2_direct_execute.rb is the hello world of BRPM)

