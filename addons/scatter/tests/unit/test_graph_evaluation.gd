extends SceneTree


func _init() -> void:
	ScatterBuiltinRegistry.register_all()
	_test_demo_build_and_determinism()
	_test_external_recipe_attachment()
	_test_type_and_cycle_rejection()
	_test_multiple_sets_and_order()
	_test_merge_disable_and_limit()
	print("Scatter graph evaluation test passed")
	quit()


func _test_demo_build_and_determinism() -> void:
	# The demo is user-editable and must not be a fixed test fixture. Build a
	# minimal typed graph here so determinism has a stable, isolated contract.
	var graph := ScatterGraph.new()
	graph.seed = 1234
	var box := ScatterBoxNode.new()
	box.size = Vector3(10.0, 0.0, 10.0)
	var random := ScatterRandomNode.new()
	random.amount = 4
	var group := ScatterGroupNode.new()
	var output := ScatterFinalOutputNode.new()
	for node in [box, random, group, output]:
		graph.add_node(node)
	graph.connect_nodes(box.node_id, &"region", group.node_id, &"region")
	graph.connect_nodes(random.node_id, &"instances", group.node_id, &"placement")
	graph.connect_nodes(group.node_id, &"set", output.node_id, &"sets")
	var target := MultiMeshInstance3D.new()
	root.add_child(target)
	_attach_recipe(target, graph, "user://scatter_graph_evaluation_determinism.tres")
	var first := ScatterBuildService.build_target(target, graph)
	var second := ScatterBuildService.build_target(target, graph)
	assert(first.ok and second.ok)
	assert(first.instances.transforms.size() == 4)
	assert(first.instances.transforms == second.instances.transforms)
	ScatterMultiMeshWriter.apply(target, first)
	assert(target.multimesh.instance_count == 4)
	target.free()


func _test_type_and_cycle_rejection() -> void:
	var graph := ScatterGraph.new()
	var box := ScatterBoxNode.new()
	var position := ScatterPositionNode.new()
	graph.add_node(box)
	graph.add_node(position)
	assert(graph.connect_nodes(box.node_id, &"region", position.node_id, &"instances") == null)
	var first := ScatterPositionNode.new()
	var second := ScatterPositionNode.new()
	graph.add_node(first)
	graph.add_node(second)
	assert(graph.connect_nodes(first.node_id, &"instances", second.node_id, &"instances") != null)
	assert(graph.connect_nodes(second.node_id, &"instances", first.node_id, &"instances") == null)


func _test_external_recipe_attachment() -> void:
	var graph := ScatterGraphFactory.create_default()
	var target := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = 1
	target.multimesh = multimesh
	var path := "user://scatter_graph_external_attachment.tres"
	_attach_recipe(target, graph, path)
	assert(ScatterGraphAttachment.get_graph(target) == graph)
	assert(ScatterGraphAttachment.get_recipe_path(target) == path)
	assert(not graph.resource_local_to_scene)
	ScatterGraphAttachment.detach(target)
	assert(ScatterGraphAttachment.get_graph(target) == null)
	assert(target.multimesh.instance_count == 1)
	assert(ResourceLoader.exists(path, "ScatterGraph"))
	target.free()


func _test_multiple_sets_and_order() -> void:
	var graph := ScatterGraph.new()
	graph.seed = 42
	var box_a := ScatterBoxNode.new()
	box_a.center = Vector3.ZERO
	box_a.size = Vector3(1, 0, 1)
	var random_a := ScatterRandomNode.new()
	random_a.amount = 3
	var group_a := ScatterGroupNode.new()
	var box_b := ScatterBoxNode.new()
	box_b.center = Vector3(10, 0, 0)
	box_b.size = Vector3(1, 0, 1)
	var random_b := ScatterRandomNode.new()
	random_b.amount = 2
	var group_b := ScatterGroupNode.new()
	var output := ScatterFinalOutputNode.new()
	for node in [box_a, random_a, group_a, box_b, random_b, group_b, output]:
		graph.add_node(node)
	graph.connect_nodes(box_a.node_id, &"region", group_a.node_id, &"region")
	graph.connect_nodes(random_a.node_id, &"instances", group_a.node_id, &"placement")
	graph.connect_nodes(box_b.node_id, &"region", group_b.node_id, &"region")
	graph.connect_nodes(random_b.node_id, &"instances", group_b.node_id, &"placement")
	graph.connect_nodes(group_b.node_id, &"set", output.node_id, &"sets", 0)
	graph.connect_nodes(group_a.node_id, &"set", output.node_id, &"sets", 1)
	var target := MultiMeshInstance3D.new()
	root.add_child(target)
	_attach_recipe(target, graph, "user://scatter_graph_evaluation_sets.tres")
	var result := ScatterBuildService.build_target(target, graph)
	assert(result.ok)
	assert(result.instances.transforms.size() == 5)
	assert(result.group_counts[group_a.node_id] == 3)
	assert(result.group_counts[group_b.node_id] == 2)
	assert(result.instances.transforms[0].origin.x > 9.0)
	target.free()


func _attach_recipe(target: MultiMeshInstance3D, graph: ScatterGraph, path: String) -> void:
	assert(ScatterRecipeIO.save_graph(graph, path) == OK)
	assert(ScatterGraphAttachment.attach(target, graph))


func _test_merge_disable_and_limit() -> void:
	var graph := ScatterGraph.new()
	var box := ScatterBoxNode.new()
	var random_a := ScatterRandomNode.new()
	random_a.amount = 3
	var random_b := ScatterRandomNode.new()
	random_b.amount = 3
	var merge := ScatterMergeNode.new()
	var position := ScatterPositionNode.new()
	position.position = Vector3(10, 0, 0)
	position.enabled = false
	var group := ScatterGroupNode.new()
	var output := ScatterFinalOutputNode.new()
	for node in [box, random_a, random_b, merge, position, group, output]:
		graph.add_node(node)
	graph.connect_nodes(box.node_id, &"region", group.node_id, &"region")
	graph.connect_nodes(random_a.node_id, &"instances", merge.node_id, &"a")
	graph.connect_nodes(random_b.node_id, &"instances", merge.node_id, &"b")
	graph.connect_nodes(merge.node_id, &"instances", position.node_id, &"instances")
	graph.connect_nodes(position.node_id, &"instances", group.node_id, &"placement")
	graph.connect_nodes(group.node_id, &"set", output.node_id, &"sets")
	var target := MultiMeshInstance3D.new()
	root.add_child(target)
	var session := ScatterEvaluationSession.new()
	var context := ScatterEvaluationContext.create(target, graph, session)
	context.maximum_instances = 4
	var value := ScatterGraphEvaluator.evaluate_node(graph, output.node_id, context) as ScatterInstanceBuffer
	assert(value != null)
	assert(value.transforms.size() == 4)
	for transform in value.transforms:
		assert(transform.origin.x < 6.0)
	target.free()
