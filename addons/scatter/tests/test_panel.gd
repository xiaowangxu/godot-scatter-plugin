extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var panel := ScatterPanel.new()
	root.add_child(panel)
	var target := MultiMeshInstance3D.new()
	target.name = "PanelTarget"
	target.multimesh = MultiMesh.new()
	target.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	target.multimesh.mesh = BoxMesh.new()
	root.add_child(target)
	panel.set_target(target)
	await process_frame
	var graph := panel.get_node("RecipeGraph") as GraphEdit
	var graph_nodes := 0
	for child in graph.get_children():
		if child is GraphNode: graph_nodes += 1
	assert(graph_nodes == 6, "Starter recipe should create four recipe nodes, one Group, and Final Output")
	assert(panel.config.group_nodes().size() == 1, "Starter recipe must contain one Scatter Group")
	assert(not panel.config.final_output_node().is_empty(), "Starter recipe must have one persistent Final Output")
	assert(panel.config.connections.size() == 5, "Starter recipe wires Region and Placement into Group, then Group into Final Output")
	var creator := graph.get_node(NodePath("2")) as GraphNode
	assert(not creator.is_slot_enabled_left(0) and creator.is_slot_enabled_right(0), "Placement creators must be output-only")
	var creator_flow := creator.get_child(0) as Label
	assert(creator_flow.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Placement output labels must align with Region outputs")
	var modifier := graph.get_node(NodePath("3")) as GraphNode
	assert(modifier.is_slot_enabled_left(0) and modifier.is_slot_enabled_right(0), "Placement modifiers must remain input/output nodes")
	assert((modifier.get_child(0) as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT)
	var result := ScatterGenerator.build(target, panel.config)
	assert(result.ok)
	assert(result.transforms.size() == 100)
	print("Scatter panel test passed: %d graph nodes, %d real connections" % [graph_nodes, panel.config.connections.size()])
	panel.free()
	target.free()
	quit(0)
