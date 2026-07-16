@tool
class_name ScatterInlineBuildScheduler
extends ScatterBuildScheduler


func submit(request: ScatterBuildRequest, completed: Callable) -> void:
	var result := backend.generate(request)
	if completed.is_valid():
		completed.call(result)
