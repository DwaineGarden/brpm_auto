# Installing BRPM Framework
- From GitHub:
1) Download the docs and framework.zip from the latest_zip folder to your machine

- On BRPM Server:
2) Create a folder on your RPM server (or attached share for cluster access) to hold the framework files (the default is in the same folder as your automation_results and named "persist")

- In BRPM:
3) Go to Environment|Metadata|Lists|Automation Categories and add a category called "Framework"
4) If you don't already have a Utility application, create one with a Utility environment and component (a good practice for running utility and cleanup requests)
5) Create a new automation, copy the contents of the install/util_f2_deployFramework.rb into the body of the automation
6) After saving, set the state of the automation to "pending" then "released"
7) Create a new request for Utility and:
	a) add a step called "Deploy Framework"
	b) pick a component and attach the new util_f2_deployFramework automation
	c) in the automation_library_path field, enter the path from step 2 (or leave blank for default path)
	d) in the upload_framework_zip field, click the "add" item and attach the downloaded zip file from above
	e) save the step
8) Plan and Start the request
