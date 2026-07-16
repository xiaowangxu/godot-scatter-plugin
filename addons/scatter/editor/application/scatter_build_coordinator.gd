@tool
class_name ScatterBuildCoordinator
extends RefCounted


class BuildBatch:
	extends RefCounted

	var targets: Array[MultiMeshInstance3D] = []
	var index := 0
	var mark_unsaved := true

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
		scene_root: Node = null,
		mark_unsaved := true,
) -> void:
	if _shutdown or not is_instance_valid(target):
		return
	var dependents := _index_dependents(scene_root)
	var queue: Array[MultiMeshInstance3D] = [target]
	var visited: Dictionary[int, bool] = {}
	var batch := BuildBatch.new()
	batch.mark_unsaved = mark_unsaved
	while not queue.is_empty():
		var current := queue.pop_front()
		if not is_instance_valid(current) or visited.has(current.get_instance_id()):
			continue
		visited[current.get_instance_id()] = true
		batch.targets.append(current)
		for dependent: MultiMeshInstance3D in dependents.get(current.get_instance_id(), []):
			if not visited.has(dependent.get_instance_id()):
				queue.append(dependent)
	_submit_next(batch)


func shutdown() -> void:
	_shutdown = true
	if scheduler != null:
		scheduler.cancel_all()


func _submit_next(batch: BuildBatch) -> void:
	if _shutdown:
		return
	while batch.index < batch.targets.size():
		var target := batch.targets[batch.index]
		batch.index += 1
		if not is_instance_valid(target):
			continue
		var graph := _resolve_graph(target)
		if graph == null:
			continue
		var request := ScatterBuildRequest.create(target, graph, null, ScatterGraphResolver.new(_resolve_graph))
		request.backend = scheduler.backend
		scheduler.submit(request, _generation_completed.bind(target, batch))
		return


func _generation_completed(
		result: ScatterBuildResult,
		target: MultiMeshInstance3D,
		batch: BuildBatch,
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
		build_succeeded.emit(target, result, batch.mark_unsaved)
	_submit_next(batch)


func _resolve_graph(target: MultiMeshInstance3D) -> ScatterGraph:
	if not is_instance_valid(target):
		return null
	if graph_provider.is_valid():
		var provided = graph_provider.call(target)
		if provided is ScatterGraph:
			return provided
	return ScatterGraphAttachment.get_graph(target)


func _index_dependents(scene_root: Node) -> Dictionary:
	var result: Dictionary = {}
	if not is_instance_valid(scene_root):
		return result
	var pending: Array[Node] = [scene_root]
	while not pending.is_empty():
		var candidate := pending.pop_front()
		pending.append_array(candidate.get_children())
		if not candidate is MultiMeshInstance3D:
			continue
		var graph := _resolve_graph(candidate)
		if graph == null:
			continue
		for node in graph.nodes:
			if not node is ScatterProxyNode or not node.enabled or not node.auto_rebuild:
				continue
			var source := candidate.get_node_or_null(node.scatter_node) as MultiMeshInstance3D
			if not is_instance_valid(source):
				continue
			var source_id := source.get_instance_id()
			if not result.has(source_id):
				result[source_id] = []
			var source_dependents := result[source_id] as Array
			if not source_dependents.has(candidate):
				source_dependents.append(candidate)
	return result
