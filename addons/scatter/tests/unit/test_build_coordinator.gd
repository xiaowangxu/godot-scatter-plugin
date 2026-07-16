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
	var target := MultiMeshInstance3D.new()
	target.name = "Target"
	root.add_child(target)

	var graph := ScatterGraphFactory.create_default()

	var provider := GraphProvider.new()
	provider.graphs[target.get_instance_id()] = graph
	var generator := GeneratorCounter.new()
	var coordinator := ScatterBuildCoordinator.new(provider.resolve, ScatterInlineBuildScheduler.new(generator))
	var built: Array[String] = []
	var mark_values: Array[bool] = []
	coordinator.build_succeeded.connect(func(built_target: MultiMeshInstance3D, _result: ScatterBuildResult, mark_unsaved: bool):
		built.append(built_target.name)
		mark_values.append(mark_unsaved)
	)
	coordinator.build(target, false)

	assert(built == ["Target"])
	assert(mark_values == [false])
	assert(generator.calls == 1)
	assert(target.multimesh != null and target.multimesh.instance_count > 0)

	# A scheduler may finish generation later. Presentation must not happen until
	# its completion callback.
	target.multimesh = null
	var manual := ManualScheduler.new(generator)
	var deferred_coordinator := ScatterBuildCoordinator.new(provider.resolve, manual)
	deferred_coordinator.build(target)
	assert(manual.requests.size() == 1 and target.multimesh == null)
	manual.complete_next()
	assert(target.multimesh != null)
	assert(manual.requests.is_empty())
	target.free()
	print("Scatter build coordinator test passed")
	quit()
