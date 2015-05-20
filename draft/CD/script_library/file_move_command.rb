@rpm.message_box "Running File Copy", "title"
result = @rpm.execute_shell("copy \"C:\\BMC\\persist\\automation_libs\" C:\\temp")
@rpm.log @rpm.display_result(result)
result = @rpm.execute_shell("dir C:\\temp\\automation_libs")
@rpm.log @rpm.display_result(result)
result = @rpm.execute_shell("rd /q /s C:\\temp\\automation_libs")
@rpm.log @rpm.display_result(result)