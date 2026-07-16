@tool
extends SceneTree


class GraphProvider:
	extends RefCounted

	var graphs: Dictionary[int, ScatterGraph] = {}

	func resolve(target: MultiMeshInstance3D) -> ScatterGraph:
		return graphs.get(target.get_instance_id())


class GeneratorCounter:
	extends ScatterGenerationBackend

	var calls := 0

	func generate(request: ScatterBuildRequest) -> ScatterBuildResult:
		calls += 1
		return ScatterBuildService.generate(request)


class ManualScheduler:
	extends ScatterBuildScheduler

	var requests: Array[ScatterBuildRequest] = []
	var completions: Array[Callable] = []

	func submit(request: ScatterBuildRequest, completed: Callable) -> void:
		requests.append(request)
		completions.append(completed)

	func complete_next() -> void:
		var request := requests.pop_front()
		var completed := completions.pop_front()
		completed.call(backend.generate(request))


func _init() -> void:
	ScatterBuiltinRegistry.register_all()
	var scene_root := Node3D.new()
	root.add_child(scene_root)
	var source := MultiMeshInstance3D.new()
	source.name = "Source"
	scene_root.add_child(source)
	var dependent := MultiMeshInstance3D.new()
	dependent.name = "Dependent"
	scene_root.add_child(dependent)

	var source_graph := ScatterGraphFactory.create_default()
	var dependent_graph := ScatterGraph.new()
	var proxy := dependent_graph.add_node(ScatterProxyNode.new()) as ScatterProxyNode
	proxy.scatter_node = NodePath("../Source")
	var output := dependent_graph.add_node(ScatterFinalOutputNode.new())
	assert(dependent_graph.connect_nodes(proxy.node_id, &"instances", output.node_id, &"instances") != null)

	var provider := GraphProvider.new()
	provider.graphs[source.get_instance_id()] = source_graph
	provider.graphs[dependent.get_instance_id()] = dependent_graph
	var generator := GeneratorCounter.new()
	var coordinator := ScatterBuildCoordinator.new(provider.resolve, ScatterInlineBuildScheduler.new(generator))
	var built: Array[String] = []
	coordinator.build_succeeded.connect(func(target: MultiMeshInstance3D, _result: ScatterBuildResult, _mark_unsaved: bool):
		built.append(target.name)
	)
	coordinator.build(source, scene_root)

	assert(built == ["Source", "Dependent"])
	assert(generator.calls == 3, "Source generation is reused by the dependent proxy build path")
	assert(source.multimesh != null and source.multimesh.instance_count > 0)
	assert(dependent.multimesh != null and dependent.multimesh.instance_count == source.multimesh.instance_count)

	# A scheduler may finish generation later. Presentation must not happen until
	# its completion callback, and dependent jobs remain ordered behind sources.
	source.multimesh = null
	dependent.multimesh = null
	var manual := ManualScheduler.new(generator)
	var deferred_coordinator := ScatterBuildCoordinator.new(provider.resolve, manual)
	deferred_coordinator.build(source, scene_root)
	assert(manual.requests.size() == 1 and source.multimesh == null)
	manual.complete_next()
	assert(source.multimesh != null and dependent.multimesh == null)
	assert(manual.requests.size() == 1)
	manual.complete_next()
	assert(dependent.multimesh != null)
	scene_root.free()
	print("Scatter build coordinator test passed")
	quit()
