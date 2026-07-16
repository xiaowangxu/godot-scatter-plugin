@tool
class_name ScatterSynchronousGenerationBackend
extends ScatterGenerationBackend


func generate(request: ScatterBuildRequest) -> ScatterBuildResult:
	return ScatterBuildService.generate(request)
