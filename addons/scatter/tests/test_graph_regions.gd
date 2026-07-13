extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var target := MultiMeshInstance3D.new()
	target.name = "GraphRegions"
	target.multimesh = MultiMesh.new()
	target.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	target.multimesh.mesh = BoxMesh.new()
	root.add_child(target)

	_test_connected_branch_only(target)
	_test_region_subtract(target)
	_test_paint_union(target)
	_test_placement_merge(target)
	_test_multiple_scatter_sets(target)
	_test_graph_invariants()

	print("Scatter graph region tests passed")
	target.free()
	quit(0)


func _test_connected_branch_only(target: MultiMeshInstance3D) -> void:
	var config := ScatterConfig.new()
	config.seed = 41
	var box := config.add_node(&"shape_box")
	var used := config.add_node(&"create_random")
	used.params.amount = 12
	var unused := config.add_node(&"create_random")
	unused.params.amount = 300
	var output := config.add_node(&"output")
	config.connect_nodes(box.id, 0, output.id, 0)
	config.connect_nodes(used.id, 0, output.id, 1)
	var result := ScatterGenerator.build(target, config)
	assert(result.ok)
	assert(result.transforms.size() == 12, "Unconnected Placement branches must not execute")
	assert(unused.id != used.id)


func _test_region_subtract(target: MultiMeshInstance3D) -> void:
	var config := ScatterConfig.new()
	config.seed = 42
	var box := config.add_node(&"shape_box")
	box.params.size = Vector3(10, 1, 10)
	var hole := config.add_node(&"shape_sphere")
	hole.params.radius = 2.0
	var subtract := config.add_node(&"region_subtract")
	var random := config.add_node(&"create_random")
	random.params.amount = 160
	var output := config.add_node(&"output")
	config.connect_nodes(box.id, 0, subtract.id, 0)
	config.connect_nodes(hole.id, 0, subtract.id, 1)
	config.connect_nodes(subtract.id, 0, output.id, 0)
	config.connect_nodes(random.id, 0, output.id, 1)
	var result := ScatterGenerator.build(target, config)
	assert(result.ok and result.transforms.size() == 160)
	for transform in result.transforms:
		assert(transform.origin.length() >= 2.0 - 0.001, "Subtract must remove the B region")


func _test_paint_union(target: MultiMeshInstance3D) -> void:
	var config := ScatterConfig.new()
	config.seed = 43
	var left := config.add_node(&"paint_region")
	left.params.strokes = [{"position": Vector3(-5, 0, 0), "normal": Vector3.UP, "radius": 2.0}]
	var right := config.add_node(&"paint_region")
	right.params.strokes = [{"position": Vector3(5, 0, 0), "normal": Vector3.UP, "radius": 2.0}]
	var union := config.add_node(&"region_union")
	var random := config.add_node(&"create_random")
	random.params.amount = 100
	var output := config.add_node(&"output")
	config.connect_nodes(left.id, 0, union.id, 0)
	config.connect_nodes(right.id, 0, union.id, 1)
	config.connect_nodes(union.id, 0, output.id, 0)
	config.connect_nodes(random.id, 0, output.id, 1)
	var result := ScatterGenerator.build(target, config)
	assert(result.ok and result.transforms.size() == 100)
	var seen_left := false
	var seen_right := false
	for transform in result.transforms:
		seen_left = seen_left or transform.origin.x < 0.0
		seen_right = seen_right or transform.origin.x > 0.0
		var center := Vector3(-5, 0, 0) if transform.origin.x < 0.0 else Vector3(5, 0, 0)
		assert(transform.origin.distance_to(center) <= 2.001, "Paint samples must stay inside a painted stamp")
	assert(seen_left and seen_right, "Union must sample both Paint Region inputs")


func _test_placement_merge(target: MultiMeshInstance3D) -> void:
	var config := ScatterConfig.new()
	config.seed = 44
	var box := config.add_node(&"shape_box")
	var a := config.add_node(&"create_random")
	a.params.amount = 7
	var b := config.add_node(&"create_random")
	b.params.amount = 9
	var merge := config.add_node(&"placement_merge")
	var output := config.add_node(&"output")
	config.connect_nodes(box.id, 0, output.id, 0)
	config.connect_nodes(a.id, 0, merge.id, 0)
	config.connect_nodes(b.id, 0, merge.id, 1)
	config.connect_nodes(merge.id, 0, output.id, 1)
	var result := ScatterGenerator.build(target, config)
	assert(result.ok and result.transforms.size() == 16, "Merge Placement must concatenate both branches once")


func _test_multiple_scatter_sets(target: MultiMeshInstance3D) -> void:
	var config := ScatterConfig.new()
	config.seed = 45
	var left_region := config.add_node(&"shape_box")
	left_region.params.center = Vector3(-10, 0, 0)
	var left_points := config.add_node(&"create_random")
	left_points.params.amount = 7
	var left_group := config.add_node(&"group")
	var right_region := config.add_node(&"shape_box")
	right_region.params.center = Vector3(10, 0, 0)
	var right_points := config.add_node(&"create_random")
	right_points.params.amount = 9
	var right_group := config.add_node(&"group")
	var final_output := config.add_node(&"final_output")
	config.connect_nodes(left_region.id, 0, left_group.id, 0)
	config.connect_nodes(left_points.id, 0, left_group.id, 1)
	config.connect_nodes(right_region.id, 0, right_group.id, 0)
	config.connect_nodes(right_points.id, 0, right_group.id, 1)
	config.connect_nodes(left_group.id, 0, final_output.id, 0)
	config.connect_nodes(right_group.id, 0, final_output.id, 1)
	var result := ScatterGenerator.build(target, config)
	assert(result.ok and result.transforms.size() == 16, "Final Output must concatenate every connected Scatter Set")
	assert(result.group_counts[left_group.id] == 7 and result.group_counts[right_group.id] == 9)
	for i in result.transforms.size():
		assert(result.transforms[i].origin.x < 0.0 if i < 7 else result.transforms[i].origin.x > 0.0, "Scatter Sets must preserve Final Output port order")


func _test_graph_invariants() -> void:
	var config := ScatterConfig.new()
	var source := config.add_node(&"shape_box")
	var output := config.add_node(&"output")
	var duplicate_output := config.add_node(&"output")
	config.connect_nodes(source.id, 0, output.id, 0)
	config.ensure_graph()
	var groups := 0
	var finals := 0
	for entry in config.nodes:
		if entry.get("type", "") == "group": groups += 1
		if entry.get("type", "") == "final_output": finals += 1
	assert(groups == 2, "Every legacy Output must migrate to an independent Scatter Group")
	assert(finals == 1, "Every recipe must keep exactly one Final Output")
	assert(config.find_node(duplicate_output.id).get("type", "") == "group", "Legacy Outputs must be preserved as Groups")
	assert(config.connections.size() == 3, "Both migrated Groups must connect to Final Output")
	assert(config.would_create_cycle(output.id, source.id), "Graph connections must reject cycles")
