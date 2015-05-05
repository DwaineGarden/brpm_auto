@rpm.message_box "Running set command", "title"
result = @rpm.execute_shell("set")
@rpm.log @rpm.display_result(result)