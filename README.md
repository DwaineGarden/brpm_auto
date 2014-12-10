# brpm_auto

## Framework and Automations for BRPM

### The BRPM Framework is a collection of libraries to enhance the capability and experience of developing automation for BRPM.

To use the framework in your environment, follow these steps:

1. Get a GitHub account and send me your ssh key so I can get you repository access

## Framework 2.0 is the most current version
2. Download the most recent framework.zip

3. View and copy the contents of the util_f2_deploy_framework.rb automation a new automation on your brpm instance

4. Create a new request (any application, I use Utility) and add a Deploy Framework step.  Assign the new deploy_framework automation to the step.

5. In the automation arguments, upload the zip file you downloaded in step 2

6. Run the request and the framework is installed

### Transport
The new framework assumes that we are taking actions against the assigned target servers.  To do this you have to have a transport agent - currently the framework supports NSH, SSH and BAA.  The framework is constructed in a two layer fashion to provide abstraction from the details of the transport agent so you can just write functional automations.

### Framework Base automations
There are several automations that provide deployment basics in a transport independent fashion
`f2_artifactPackaging` - this automation takes file artifacts from either a VersionTag, paths entered in the arguments or files directly uploaded into the step. It then invokes the transfer agent (nsh, ssh or baa) to copy and package the files into an archive.
`f2_artifactDeploy` - this automation deploys the package from packaging to the assigned step targets
`demo_flow - brpd actions` - these automations demonstrate how to execute an embedded shell script on remote targets
`f2_executeLibraryAction` - this automation executes a shell script from a file library (alternate version updates the library from git)

## Framework 1.0 Instructions
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

