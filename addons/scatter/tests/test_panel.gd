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
	assert(graph_nodes == 5, "Starter recipe should create four recipe nodes plus one Output node")
	assert(not panel.config.output_node().is_empty(), "Starter recipe must have one persistent Output node")
	assert(panel.config.connections.size() == 4, "Starter recipe wires Region and Placement into Output")
	var result := ScatterGenerator.build(target, panel.config)
	assert(result.ok)
	assert(result.transforms.size() == 100)
	print("Scatter panel test passed: %d graph nodes, %d real connections" % [graph_nodes, panel.config.connections.size()])
	panel.free()
	target.free()
	quit(0)
