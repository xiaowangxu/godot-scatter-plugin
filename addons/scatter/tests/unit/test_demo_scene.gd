extends SceneTree


func _init() -> void:
	ScatterBuiltinRegistry.register_all()
	var packed := load("res://addons/scatter/demo/scatter_demo.tscn") as PackedScene
	assert(packed != null)
	var scene := packed.instantiate()
	root.add_child(scene)
	var built := 0
	for child in scene.get_children():
		if not child is MultiMeshInstance3D:
			continue
		var target := child as MultiMeshInstance3D
		var graph := ScatterGraphAttachment.get_graph(target)
		assert(graph != null)
		var result := ScatterBuildService.build_target(target, graph)
		assert(result.ok, result.error)
		ScatterMultiMeshWriter.apply(target, result)
		assert(target.multimesh != null)
		assert(target.multimesh.instance_count == result.instances.transforms.size())
		built += 1
	assert(built > 0, "The demo scene must contain at least one buildable Scatter target")
	scene.free()
	print("Scatter demo scene test passed")
	quit()
