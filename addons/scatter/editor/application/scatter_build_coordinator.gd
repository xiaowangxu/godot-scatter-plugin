@tool
class_name ScatterBuildCoordinator
extends RefCounted

signal build_succeeded(target: MultiMeshInstance3D, result: ScatterBuildResult, mark_unsaved: bool)
signal build_failed(target: MultiMeshInstance3D, result: ScatterBuildResult)

var graph_provider: Callable
var scheduler: ScatterBuildScheduler
var _shutdown := false


func _init(
		p_graph_provider := Callable(),
		p_scheduler: ScatterBuildScheduler = null,
) -> void:
	graph_provider = p_graph_provider
	scheduler = p_scheduler if p_scheduler != null else ScatterInlineBuildScheduler.new()


func build(
		target: MultiMeshInstance3D,
		mark_unsaved := true,
) -> void:
	if _shutdown or not is_instance_valid(target):
		return
	var graph := _resolve_graph(target)
	if graph == null:
		return
	var request := ScatterBuildRequest.create(target, graph)
	scheduler.submit(request, _generation_completed.bind(target, mark_unsaved))


func shutdown() -> void:
	_shutdown = true
	if scheduler != null:
		scheduler.cancel_all()


func _generation_completed(
		result: ScatterBuildResult,
		target: MultiMeshInstance3D,
		mark_unsaved: bool,
) -> void:
	if _shutdown:
		return
	if result == null:
		result = ScatterBuildResult.failure("The Scatter generation backend returned no result.")
	if not result.ok:
		build_failed.emit(target, result)
	elif is_instance_valid(target):
		# Schedulers must deliver completion on the editor thread. Generation may
		# run elsewhere, while MultiMesh presentation always stays here.
		ScatterMultiMeshWriter.apply(target, result)
		build_succeeded.emit(target, result, mark_unsaved)


func _resolve_graph(target: MultiMeshInstance3D) -> ScatterGraph:
	if not is_instance_valid(target):
		return null
	if graph_provider.is_valid():
		var provided = graph_provider.call(target)
		if provided is ScatterGraph:
			return provided
	return ScatterGraphAttachment.get_graph(target)
