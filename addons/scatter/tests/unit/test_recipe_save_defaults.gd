extends SceneTree


func _init() -> void:
	ScatterBuiltinRegistry.register_all()
	var recipe_path := "user://scatter_recipe_save_defaults_test.tres"
	var initial := ScatterGraph.new()
	var initial_node := ScatterShapeTransformNode.new()
	initial_node.position = Vector3(0, 10, 0)
	initial_node.rotation = Vector3(0, 60, 0)
	initial_node.scale = Vector3(2, 1, 1)
	initial.add_node(initial_node)
	assert(ResourceSaver.save(initial, recipe_path) == OK)

	var source := ResourceLoader.load(
		recipe_path,
		"ScatterGraph",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as ScatterGraph
	assert(source != null)
	var source_node := source.find_node(initial_node.node_id) as ScatterShapeTransformNode
	assert(source_node != null)
	var session := ScatterRecipeEditSession.create(source)
	assert(session != null)
	var working_node := session.working_graph.find_node(
		initial_node.node_id
	) as ScatterShapeTransformNode
	working_node.position = Vector3.ZERO
	working_node.rotation = Vector3.ZERO
	working_node.scale = Vector3.ONE

	assert(session.save() == OK)
	assert(session.source_graph == source)
	assert(source.find_node(initial_node.node_id) == source_node)
	assert(source_node.position == Vector3.ZERO)
	assert(source_node.rotation == Vector3.ZERO)
	assert(source_node.scale == Vector3.ONE)
	var loaded := ResourceLoader.load(
		recipe_path,
		"ScatterGraph",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as ScatterGraph
	var loaded_node := loaded.find_node(initial_node.node_id) as ScatterShapeTransformNode
	assert(loaded_node.position == Vector3.ZERO)
	assert(loaded_node.rotation == Vector3.ZERO)
	assert(loaded_node.scale == Vector3.ONE)

	ScatterBuiltinRegistry.unregister_all()
	print("Scatter recipe default save test passed")
	quit()
