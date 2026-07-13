extends SceneTree


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

	var compiler := ScatterGraphCompiler.compile(graph)
	assert(not compiler.has_errors())
	assert(compiler.ordered_node_ids.size() == graph.nodes.size())

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
	target.free()
	print("Scatter graph evaluation test passed")
	quit()
