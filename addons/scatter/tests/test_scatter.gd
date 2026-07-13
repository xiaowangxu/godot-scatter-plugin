extends SceneTree


func _init() -> void:
	var target := MultiMeshInstance3D.new()
	target.name = "ScatterTest"
	target.multimesh = MultiMesh.new()
	target.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	target.multimesh.mesh = BoxMesh.new()
	var config := ScatterConfig.new()
	config.seed = 12345
	config.add_node(&"shape_box").params.size = Vector3(10, 2, 10)
	config.add_node(&"shape_sphere").params.merge({"center": Vector3(0, 0, 0), "radius": 1.0, "negative": true}, true)
	config.add_node(&"create_random").params.amount = 128
	config.add_node(&"random_rotation").params.rotation = Vector3(0, 180, 0)
	config.add_node(&"random_transform").params.scale = Vector3(0.2, 0.2, 0.2)
	config.add_node(&"remove_outside")
	config.add_node(&"random_color").params.merge({"from": Color.RED, "to": Color.BLUE}, true)
	var a := ScatterGenerator.build(target, config)
	var b := ScatterGenerator.build(target, config)
	assert(a.ok and b.ok)
	assert(a.transforms.size() == 128)
	assert(a.transforms == b.transforms, "A fixed seed must be deterministic")
	for transform in a.transforms:
		assert(transform.origin.length() >= 1.0, "Negative sphere must exclude points")
	ScatterGenerator.apply_to_multimesh(target, a)
	assert(target.multimesh.instance_count == 128)
	assert(target.multimesh.use_colors)
	print("Scatter tests passed: %d deterministic instances" % target.multimesh.instance_count)
	target.free()
	quit(0)
