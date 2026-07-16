@tool
@abstract
class_name ScatterBuildScheduler
extends RefCounted

var backend: ScatterGenerationBackend


func _init(p_backend: ScatterGenerationBackend = null) -> void:
	backend = p_backend if p_backend != null else ScatterSynchronousGenerationBackend.new()


@abstract func submit(request: ScatterBuildRequest, completed: Callable) -> void


func cancel_all() -> void:
	pass
