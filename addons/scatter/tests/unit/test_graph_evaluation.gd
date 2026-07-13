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
	var incompatible := MultiMesh.new()
	incompatible.transform_format = MultiMesh.TRANSFORM_2D
	incompatible.instance_count = 3
	target.multimesh = incompatible
	ScatterMultiMeshWriter.apply(target, first)
	assert(target.multimesh != incompatible)
	assert(target.multimesh.transform_format == MultiMesh.TRANSFORM_3D)
	assert(target.multimesh.use_colors and target.multimesh.use_custom_data)
	assert(target.multimesh.instance_count == 100)

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

	var geometry_graph := ScatterGraph.new()
	var box := ScatterBoxNode.new()
	var path := ScatterPathNode.new()
	path.points = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 4)])
	var shape_transform := ScatterShapeTransformNode.new()
	shape_transform.position = Vector3(3, 0, 0)
	var random := ScatterRandomNode.new()
	random.amount = 12
	var along_path := ScatterEdgeEvenNode.new()
	along_path.spacing = 1.0
	var geometry_output := ScatterFinalOutputNode.new()
	for node in [box, path, shape_transform, random, along_path, geometry_output]:
		geometry_graph.add_node(node)
	geometry_graph.connect_nodes(box.node_id, &"region", shape_transform.node_id, &"shape")
	geometry_graph.connect_nodes(path.node_id, &"path", shape_transform.node_id, &"path")
	geometry_graph.connect_nodes(shape_transform.node_id, &"shape", random.node_id, &"shape")
	geometry_graph.connect_nodes(shape_transform.node_id, &"path", along_path.node_id, &"path")
	geometry_graph.connect_nodes(random.node_id, &"instances", geometry_output.node_id, &"instances", 0)
	geometry_graph.connect_nodes(along_path.node_id, &"instances", geometry_output.node_id, &"instances", 1)
	var geometry_result := ScatterBuildService.build_target(target, geometry_graph)
	assert(geometry_result.ok)
	assert(geometry_result.instances.transforms.size() > random.amount)
	target.free()
	print("Scatter graph evaluation test passed")
	quit()
