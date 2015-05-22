## Framework and Automations for BRPM

### The BRPM Framework is a collection of libraries to enhance the capability and experience of developing automation for BRPM.
### Framework 2.0 is the most current version

To use the framework in your environment, follow these steps:

1. Get a GitHub account and send me your ssh key so I can get you repository access

2. Download the most recent framework.zip (2.05) and rdoc html documentation from the latest_zip folder

3. Decide where on your installation that you would like to store the framework files (default is RLM/persist)

4. View and copy the contents of the `util_f2_deploy_framework.rb` automation to a new automation on your brpm instance

5. Create a new request (any application, I use Utility) and add a Deploy Framework step.  Assign the new deploy_framework automation to the step.

6. In the automation arguments, upload the zip file you downloaded in step 2

7. Run the request and the framework is installed

8. Now go to the framework folder (usually automation_lib) and edit the customer_include.rb file.  In here you should enter paths and constants for things like the automation token for rest calls, paths to bladelogic, script libraries etc.  Put anything in there that you want to be available to all your automations.

*Note: the install automation makes direct modifications to the standard ssh_script_header.rb file in RPM/lib/script_support.  This allows the framework to be available and operating for all automations.  If you would prefer to not have the framework loaded automatically, edit the ssh_script_header.rb file and remove the few lines at the top of the file (down to where it says #End of framework additions).  The other thing to do is rename the method: orig_load_input_params to load_input_params.  Then, to use the framework, you will need to include a line in your automations like this:
`require "C:/BMC/persist/automation_lib/brpm_framework"`

## Transport
The new framework assumes that we are performaing actions against the assigned target servers.  To do this you have to have a transport agent - currently the framework supports NSH, SSH and BAA.  The framework is constructed in a two layer fashion to provide abstraction from the details of the transport agent so you can just write functional automations.
#### How does it work?
For each agent protocol there are two classes, a Transport class that interacts with the specific capabilities and a Dispatch class that provides the high-level capabilities. For example, for NSH, the TransportNSH class has all the nexec, ncp, scriptutil, proxy interactions etc.  The DispatchNSH class has high level routines like `package_artifacts` and `script_execute`

### Framework Base automations
There are several automations that provide deployment basics in a transport independent fashion 

`f2_artifactPackaging` - this automation takes file artifacts from either a VersionTag, paths entered in the arguments or files directly uploaded into the step. It then invokes the transfer agent (nsh, ssh or baa) to copy and package the files into an archive. 

`f2_artifactDeploy` - this automation deploys the package from packaging to the assigned step targets 

`demo_flow - brpd actions` - these automations demonstrate how to execute an embedded shell script on remote targets 

`f2_executeLibraryAction` - this automation executes a shell script from a file library (alternate version updates the library from git)

`f2_direct_execute.rb` - this is the hello world of BRPM.  It takes whatever you enter in command and executes it on the command line of the local server.  If you enter a success argument, success of the automation will depend on finding that string in the output of your command.

There are lots of other automations in there, read and experiment!

## Getting Started
1. Create a request

2. Create a step, add a component and choose the automation "f2_directExecute".  In the arguments enter:
 Command: echo "RPM using: ${SS_application} in ${SS_environment}"  & env    (# windows, substitute set for env)
 Success: PATH
 Save the step and continue
 
3. Create a dummy step called check to keep the request from completing

4. Plan and Start the request.  When the step completes, take a look at the notes page, click on the Automation_run_full_results link

5. Take a look at the automation code.  Note where it gets the value for the command argument `@p.get("command")`.  This is invoking the Param class.  The get method searches for embedded property values inside the ${} and resolves them for you. 

6. Now lets look at the ouput:

`===================== RESULTS =====================================================`

`08:49:48|INFO> Loading customer include file: /opt/bmc/persist/automation_lib/customer_include.rb`<br>
`08:49:48|INFO> Request Run Data: http://clm-aus-006997.bmc.com:8080/brpm/automation_results/request/BRPM/1002/request_data.json`<br>
`08:49:48|INFO> request_data_file => Created 05/21/2015 14:41:14`<br>
`08:49:48|INFO> ss_transport => nsh`<br>
`08:49:48|INFO> ##------ End of Local Params --------##`<br>
`08:49:48|INFO> Loading transport modules for: nsh`<br>
`08:49:48|INFO> Initializing nsh transport`<br>
`08:49:48|INFO> Path to nsh: /opt/bmc/bladelogic/NSH`<br>
`08:49:48|INFO> Success - found term: PATH`<br>
`New Run - Shell Cmd: echo "RPM using: ${SS_application} in ${SS_environment}"  & env`<br>
`========================`<br>
` Running: echo "RPM using: BRPM in CI"  & env `<br>
`========================`<br>
`WKHTMLTOPDF_HOME=/opt/bmc/RLM/lib/wkhtmltopdf`<br>
`HOSTNAME=clm-aus-006997`<br>

7. Note what the framework has added:
	All output is now timestamped in log format (when you use @rpm.log)
	The request_data.json file is automatically created and loaded for you and available in the Param class instance (@p.get searches that too!)
	Default transport automation has been initialized for nsh (in the absence of the property "SS_transport" it will default to nsh)
	Transport will create two classes: @transport, an instance of the DispatchNSH class, and @nsh, an instance of TransportNSH.  These contain high
	level methods to leverage nsh to work on remote servers.