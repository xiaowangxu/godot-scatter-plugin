extends SceneTree


class PersistentTestCache:
	extends ScatterEvaluationCache

	var entries: Dictionary[String, ScatterNodeOutputs] = {}

	func has_outputs(context: ScatterEvaluationContext, node_id: int) -> bool:
		return entries.has(_key(context, node_id))

	func get_outputs(context: ScatterEvaluationContext, node_id: int) -> ScatterNodeOutputs:
		return entries.get(_key(context, node_id))

	func store_outputs(context: ScatterEvaluationContext, node_id: int, outputs: ScatterNodeOutputs) -> void:
		entries[_key(context, node_id)] = outputs

	func clear() -> void:
		entries.clear()

	func _key(context: ScatterEvaluationContext, node_id: int) -> String:
		return "%d:%d:%d" % [context.graph.get_instance_id(), context.target.get_instance_id(), node_id]


func _init() -> void:
	ScatterBuiltinRegistry.register_all()
	var graph := ScatterGraphFactory.create_default()
	var target := MultiMeshInstance3D.new()
	root.add_child(target)
	var first := ScatterBuildService.build_target(target, graph)
	var second := ScatterBuildService.build_target(target, graph)
	assert(first.ok and second.ok)
	assert(first.instances.transforms.size() == 100)
	assert(first.instances.transforms == second.instances.transforms)
	assert(first.errors.is_empty())
	assert(not first.output_counts.is_empty())
	ScatterMultiMeshWriter.apply(target, first)
	assert(target.multimesh.instance_count == 100)
	assert(target.multimesh.buffer.size() == 100 * 20)
	var first_transform := first.instances.transforms[0]
	var first_buffer := target.multimesh.buffer
	assert(is_equal_approx(first_buffer[0], first_transform.basis.x.x))
	assert(is_equal_approx(first_buffer[1], first_transform.basis.y.x))
	assert(is_equal_approx(first_buffer[2], first_transform.basis.z.x))
	assert(is_equal_approx(first_buffer[3], first_transform.origin.x))
	assert(is_equal_approx(first_buffer[12], first.instances.colors[0].r))
	assert(is_equal_approx(first_buffer[16], first.instances.custom_data[0].r))
	var incompatible := MultiMesh.new()
	incompatible.transform_format = MultiMesh.TRANSFORM_2D
	incompatible.instance_count = 3
	target.multimesh = incompatible
	ScatterMultiMeshWriter.apply(target, first)
	assert(target.multimesh != incompatible)
	assert(target.multimesh.transform_format == MultiMesh.TRANSFORM_3D)
	assert(target.multimesh.use_colors and target.multimesh.use_custom_data)
	assert(target.multimesh.instance_count == 100)
	var shared_session := ScatterEvaluationSession.new()
	assert(ScatterBuildService.build_target(target, graph, shared_session).ok)
	assert(ScatterBuildService.build_target(target, graph, shared_session).ok)
	assert(shared_session.evaluation_cache_hits == 0, "Ephemeral cache entries must not leak across build executions")
	assert(shared_session.execution_id == 2)
	var persistent_session := ScatterEvaluationSession.new(PersistentTestCache.new())
	assert(ScatterBuildService.build_target(target, graph, persistent_session).ok)
	var cached_build := ScatterBuildService.build_target(target, graph, persistent_session)
	assert(cached_build.ok)
	assert(persistent_session.evaluation_cache_hits == graph.nodes.size())
	assert(not cached_build.output_counts.is_empty())

	var compiler := ScatterGraphCompiler.compile(graph)
	assert(not compiler.has_errors())
	assert(compiler.ordered_node_ids.size() == graph.nodes.size())
	var random_node := graph.find_first(&"create_random")
	var preview_plan := ScatterGraphCompiler.compile_node(graph, random_node.node_id)
	assert(not preview_plan.has_errors())
	assert(preview_plan.ordered_node_ids.size() == 2)
	assert(not preview_plan.ordered_node_ids.has(graph.final_output_node().node_id))
	var cyclic := ScatterGraphFactory.create_default()
	var cycle_a := cyclic.add_node(ScatterTransformNode.new())
	var cycle_b := cyclic.add_node(ScatterTransformNode.new())
	cyclic.connections.append(ScatterConnection.create(cycle_a.node_id, &"instances", cycle_b.node_id, &"instances"))
	cyclic.connections.append(ScatterConnection.create(cycle_b.node_id, &"instances", cycle_a.node_id, &"instances"))
	var cycle_plan := ScatterGraphCompiler.compile(cyclic)
	assert(cycle_plan.has_errors())
	assert(cycle_plan.diagnostics.any(func(diagnostic: ScatterDiagnostic): return diagnostic.code == &"cycle"))

	var multi := ScatterGraph.new()
	var a := ScatterSingleNode.new()
	a.offset = Vector3(1, 0, 0)
	var b := ScatterSingleNode.new()
	b.offset = Vector3(2, 0, 0)
	var output := ScatterFinalOutputNode.new()
	for node in [a, b, output]:
		multi.add_node(node)
	multi.connect_nodes(b.node_id, &"instances", output.node_id, &"instances", 0)
	multi.connect_nodes(a.node_id, &"instances", output.node_id, &"instances", 1)
	var ordered := ScatterBuildService.build_target(target, multi)
	assert(ordered.ok)
	assert(ordered.instances.transforms[0].origin == Vector3(2, 0, 0))
	assert(ordered.instances.transforms[1].origin == Vector3(1, 0, 0))

	var geometry_graph := ScatterGraph.new()
	var box := ScatterBoxNode.new()
	var path := ScatterPathNode.new()
	path.points = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 4)])
	var region_transform := ScatterShapeTransformNode.new()
	region_transform.position = Vector3(3, 0, 0)
	var path_transform := ScatterShapeTransformNode.new()
	path_transform.position = Vector3(3, 0, 0)
	var random := ScatterRandomNode.new()
	random.amount = 12
	var along_path := ScatterEdgeEvenNode.new()
	along_path.spacing = 1.0
	var geometry_output := ScatterFinalOutputNode.new()
	for node in [box, path, region_transform, path_transform, random, along_path, geometry_output]:
		geometry_graph.add_node(node)
	geometry_graph.connect_nodes(box.node_id, &"region", region_transform.node_id, &"geometry")
	geometry_graph.connect_nodes(path.node_id, &"path", path_transform.node_id, &"geometry")
	geometry_graph.connect_nodes(region_transform.node_id, &"geometry", random.node_id, &"shape")
	geometry_graph.connect_nodes(path_transform.node_id, &"geometry", along_path.node_id, &"path")
	assert(region_transform.geometry_type == ScatterValueTypeRegistry.REGULAR_REGION)
	assert(path_transform.geometry_type == ScatterValueTypeRegistry.PATH)
	geometry_graph.connect_nodes(random.node_id, &"instances", geometry_output.node_id, &"instances", 0)
	geometry_graph.connect_nodes(along_path.node_id, &"instances", geometry_output.node_id, &"instances", 1)
	var geometry_result := ScatterBuildService.build_target(target, geometry_graph)
	assert(geometry_result.ok)
	assert(geometry_result.instances.transforms.size() > random.amount)

	var adaptive_graph := ScatterGraph.new()
	var adaptive_box := ScatterBoxNode.new()
	var adaptive_region := ScatterPaintRegionNode.new()
	var adaptive_shape := ScatterUnionNode.new()
	var adaptive_path := ScatterPathNode.new()
	var adaptive_transform := ScatterShapeTransformNode.new()
	var adaptive_random := ScatterRandomNode.new()
	var adaptive_along_path := ScatterEdgeEvenNode.new()
	for node in [adaptive_box, adaptive_region, adaptive_shape, adaptive_path, adaptive_transform, adaptive_random, adaptive_along_path]:
		adaptive_graph.add_node(node)
	assert(adaptive_graph.connect_nodes(adaptive_box.node_id, &"region", adaptive_transform.node_id, &"geometry") != null)
	assert(adaptive_transform.geometry_type == ScatterValueTypeRegistry.REGULAR_REGION)
	assert(adaptive_graph.connect_nodes(adaptive_region.node_id, &"region", adaptive_transform.node_id, &"geometry") != null)
	assert(adaptive_transform.geometry_type == ScatterValueTypeRegistry.REGION)
	assert(adaptive_graph.connect_nodes(adaptive_shape.node_id, &"shape", adaptive_transform.node_id, &"geometry") != null)
	assert(adaptive_transform.geometry_type == ScatterValueTypeRegistry.SHAPE)
	assert(adaptive_graph.connect_nodes(adaptive_path.node_id, &"path", adaptive_transform.node_id, &"geometry") != null)
	assert(adaptive_transform.geometry_type == ScatterValueTypeRegistry.PATH)
	assert(adaptive_graph.connect_nodes(adaptive_transform.node_id, &"geometry", adaptive_along_path.node_id, &"path") != null)
	# Path is also a Shape, so a Shape consumer must preserve the more precise
	# Path type and all existing Path connections.
	assert(adaptive_graph.connect_nodes(adaptive_transform.node_id, &"geometry", adaptive_random.node_id, &"shape") != null)
	assert(adaptive_transform.geometry_type == ScatterValueTypeRegistry.PATH)
	assert(adaptive_graph.incoming_connections(adaptive_transform.node_id, &"geometry").size() == 1)
	assert(adaptive_graph.outgoing_connections(adaptive_transform.node_id).size() == 2)
	assert(adaptive_graph.disconnect_nodes(adaptive_transform.node_id, &"geometry", adaptive_random.node_id, &"shape") != null)
	assert(adaptive_transform.geometry_type == ScatterValueTypeRegistry.PATH)
	target.free()
	print("Scatter graph evaluation test passed")
	quit()
