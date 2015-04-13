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
		<BMA_WORKING>
			configurations
			install
			preview
			reports
			server_profiles
			snapshots
			tmp
			
#=> Snapshot Compare
	Inportant - two properties need to be set BMA_COMPARE_SNAPSHOT1 and BMA_COMPARE_SNAPSHOT2
	