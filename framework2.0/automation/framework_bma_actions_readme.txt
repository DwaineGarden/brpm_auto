#---------------------------------------------------------------------------#
#     Working with BMA Actions in the Framework
#---------------------------------------------------------------------------#
3-31-15 BJB

BMA Actions provide an easy wrapper for working with BMA to manage configurations in a Websphere Environment

#=> Key Concepts
	BMA actions all take place on the BMA server, not the step assigned servers
	The BMA server should be spcified as an integration referenced in the automation
	BMA actions assume that all the interaction with source control (where BMA artifacts are stored) is done in a separate step
	Most nameing should be rule-based to avoid having to parameterize everything too much
	
#=> Typical Request Flow
	1) Stage artifacts from source control
		This is where we pull configurations and archive files from the source control on the BMA server
	2) Start/Stop services if necessary
		This will call a WSAdmin (for WebSphere) script on the target cell DMGR
	3) Perform BMA Action
		This will perform the Snapshot, Preview, Install step
	4) Start/Stop services if necessary
	
#=> Conventions
	BMA working directories are assumed to be:
		<BMA_WORKING>/
			configurations/
				<app>/
					<config>-res.xml
					<config>-res-d.xml
					<config>-app.xml
					<config>-app-d.xml
					
			install/
			preview/
			reports/
			serverprofiles/
				<environment>/
					<server_dns>.serverprofile
			snapshots/
			tmp/
			
#=> Snapshot Compare
	Inportant - two properties need to be set BMA_COMPARE_SNAPSHOT1 and BMA_COMPARE_SNAPSHOT2
	
	
#=> How the integration works:
BMA has a full featured command line interface (CLI).  The RPM integration uses NSH to communicate to the BMA server and then call a shell script to address the CLI.  A typical CLI call (from the shell script) looks like this:

${BMA_DIR}/cli/runDeliver.sh -properties ${BMA_PROP} -license ${BMA_LIC} -logLevel ${LOG_LEVEL} -mode ${BMA_ACTION} -config ${CONFIG_FILE} -profile ${CLEARCASE_VIEW}/serverprofiles/$ENV/${BMA_SERVER_PROF} -report ${BMA_WORKING}/reports/${ENV}_${APP}_${BMA_ACTION}Report_${DATE}.report -syncnodes"

Thus we need to have properties to supply all these values.  
RPM passes all the properties to the shell script using an erb template for the script:

#####Variables
BMA_DIR=<%=@bma["home_dir"] %>
LOG_LEVEL=<%=@bma["log_level"] %>
BMA_LIC=<%=@bma["license"] %>
BMA_PROP=<%=bma_properties_path %>
BMA_OPTIONS="-properties ${BMA_PROP} -license ${BMA_LIC} -logLevel ${LOG_LEVEL}"
BMA_WORKING=<%=@bma["working_dir"] %>
BMA_CONFIG_PACKAGE=<%=File.basename(bma_config_package_path) %>
BMA_MODE=<%=@bma["action"] %>
BMA_SERVER_PROFILE=<%=File.basename(bma_server_profile_path) %>
BMA_SERVER_PROFILES_DIR=<%=File.dirname(bma_server_profile_path) %>
BMA_CONFIG_PACKAGES_DIR=<%=File.dirname(bma_config_package_path) %>
BMA_TOKEN_SET=<%=bma_tokenset_name %>
BMA_SNAPSHOTS_DIR=<%=@bma["snapshots_path"] %>
BMA_ARCHIVE_DIR=<%=@bma["archive_path"] %>
BMA_REPORTS_DIR=<%=@bma["reports_path"] %>

The values can be broken down into 3 categories:
1) Values that are intrinsic to the BMA Server:
(These are in the RPM Integration record)
	BMA_DIR - path to BMA installation
	BMA_PROP - path to BMA properties configuration file
	BMA_LIC - path to the license file
	BMA_WORKING - path to the workspace folder for BMA (usually in source control)
2) Values that follow the application/component/environment:
(These are in component properties)
	BMA_SERVER_PROFILE
	BMA_CONFIG_PACKAGE
	BMA_TOKEN_SET
3) Values pertaining to the individual run:
(These are set by rules or in the step script arguments)
	LOG_LEVEL
	SNAPSHOT_NAME
	REPORT_NAME e.g. ${ENV}_${APP}_${BMA_ACTION}Report_${DATE}.report
	
The BRPM integration record includes a details field which we populate with YAML information.  Here's a sample:

#=== General Integration Server: BMA Sandbox ===#
# [integration_id=10100]
SS_integration_dns = "lwtd014.hhscie.txaccess.net"
SS_integration_username = "bmaadmin"
SS_integration_password = "-private-"
SS_integration_details = "BMA_HOME: /bmc/bma/BLAppRelease-8.5.0.a557498.gtk.linux.x86_64
BMA_LICENSE: /bmc/bma/BLAppRelease-8.5.0.a557498.gtk.linux.x86_64/TexasHealth5997ELO_ML.lic
BMA_WORKING: /bmc/bma_working
BMA_PLATFORM: Linux"
SS_integration_password_enc = "__SS__Cj00V2F0UldZaDFtWQ=="
#=== End ===#




