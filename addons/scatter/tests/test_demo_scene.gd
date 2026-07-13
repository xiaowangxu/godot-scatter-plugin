extends SceneTree


func _init() -> void:
	var packed := load("res://addons/scatter/demo/scatter_demo.tscn") as PackedScene
	assert(packed != null)
	var scene := packed.instantiate()
	root.add_child(scene)
	var target := scene.get_node("ScatteredCubes") as MultiMeshInstance3D
	assert(target != null and target.has_meta(ScatterGenerator.META_KEY))
	var config := target.get_meta(ScatterGenerator.META_KEY) as ScatterConfig
	assert(config != null and config.version == 3)
	assert(config.connections.size() == 8)
	var paint_nodes := 0
	var group_nodes := 0
	var final_nodes := 0
	for entry in config.nodes:
		paint_nodes += 1 if entry.get("type", "") == "paint_region" else 0
		group_nodes += 1 if entry.get("type", "") == "group" else 0
		final_nodes += 1 if entry.get("type", "") == "final_output" else 0
	assert(paint_nodes == 1 and group_nodes == 2 and final_nodes == 1)
	var final_output := config.final_output_node()
	assert(not config.incoming_connection(final_output.id, 0).is_empty())
	assert(not config.incoming_connection(final_output.id, 1).is_empty())
	var result := ScatterGenerator.build(target, config)
	assert(result.ok and result.transforms.size() == 104)
	assert(result.group_counts.size() == 2)
	print("Scatter demo test passed: %d nodes, %d connections, %d instances" % [config.nodes.size(), config.connections.size(), result.transforms.size()])
	scene.free()
	quit(0)
