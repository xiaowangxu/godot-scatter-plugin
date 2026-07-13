extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var target := _make_target("AllOperations")
	root.add_child(target)
	var creators := ScatterConfig.new()
	creators.seed = 77
	creators.add_node(&"shape_box").params.merge({"size": Vector3(4, 2, 4), "rotation": Vector3(0, 20, 0)}, true)
	creators.add_node(&"shape_path").params.merge({"points": PackedVector3Array([Vector3(-2, 0, -2), Vector3(2, 0, -2), Vector3(2, 0, 2)]), "thickness": 0.5}, true)
	creators.add_node(&"create_random").params.amount = 8
	creators.add_node(&"create_grid").params.spacing = Vector3(2, 2, 2)
	var poisson := creators.add_node(&"create_poisson"); poisson.params.radius = 0.8; poisson.params.max_points = 12
	creators.add_node(&"edge_random").params.instance_count = 4
	creators.add_node(&"edge_even").params.spacing = 2.0
	creators.add_node(&"edge_continuous").params.item_length = 2.0
	creators.add_node(&"single")
	var array := creators.add_node(&"array"); array.params.amount = 1; array.params.randomize_indices = true
	var creation_result := ScatterGenerator.build(target, creators)
	assert(creation_result.ok and not creation_result.transforms.is_empty())
	assert(creation_result.transforms == ScatterGenerator.build(target, creators).transforms, "Every creator must be deterministic")

	var modifiers := ScatterConfig.new()
	modifiers.seed = 88
	modifiers.manual_transforms = creation_result.transforms.slice(0, mini(24, creation_result.transforms.size()))
	modifiers.add_node(&"shape_box").params.size = Vector3(20, 20, 20)
	modifiers.add_node(&"transform").params.merge({"position": Vector3(0.1, 0, 0), "rotation": Vector3(0, 5, 0)}, true)
	modifiers.add_node(&"position").params.position = Vector3(0.1, 0, 0)
	modifiers.add_node(&"rotation").params.rotation = Vector3(0, 10, 0)
	modifiers.add_node(&"scale").params.scale = Vector3(1.1, 1.1, 1.1)
	modifiers.add_node(&"random_transform").params.merge({"position": Vector3(0.1, 0.1, 0.1), "rotation": Vector3(5, 5, 5), "scale": Vector3(0.1, 0.1, 0.1)}, true)
	modifiers.add_node(&"random_rotation").params.merge({"rotation": Vector3(0, 90, 0), "snap_angle": Vector3(0, 15, 0)}, true)
	modifiers.add_node(&"look_at").params.target = Vector3(0, 0, 10)
	modifiers.add_node(&"snap").params.position_step = Vector3(0.01, 0.01, 0.01)
	var relax := modifiers.add_node(&"relax"); relax.params.iterations = 1; relax.params.offset_step = 0.001
	modifiers.add_node(&"project").params.remove_points_on_miss = false
	modifiers.add_node(&"remove_outside")
	modifiers.add_node(&"remove_random").params.probability = 0.0
	modifiers.add_node(&"random_color").params.merge({"from": Color.RED, "to": Color.BLUE}, true)
	modifiers.add_node(&"random_custom_data")
	var modified := ScatterGenerator.build(target, modifiers)
	assert(modified.ok and not modified.transforms.is_empty())
	assert(modified.colors.size() == modified.transforms.size())
	assert(modified.custom_data.size() == modified.transforms.size())
	for transform in modified.transforms:
		assert(transform.origin.is_finite() and transform.basis.is_finite())
	var clustered := ScatterConfig.new()
	clustered.manual_transforms = [Transform3D(Basis(), Vector3.ZERO)]
	var cluster_node := clustered.add_node(&"clusterize")
	cluster_node.params.merge({"mask": "res://icon.svg", "remove_below": 0.0, "remove_above": 1.0, "scale_transforms": false}, true)
	assert(ScatterGenerator.build(target, clustered).transforms.size() == 1)

	var source := _make_target("Source")
	root.add_child(source)
	var source_config := ScatterConfig.new(); source_config.add_node(&"single").params.offset = Vector3(3, 0, 0)
	source.set_meta(ScatterGenerator.META_KEY, source_config)
	var proxy_config := ScatterConfig.new(); proxy_config.add_node(&"proxy").params.scatter_node = NodePath("../Source")
	var proxy_result := ScatterGenerator.build(target, proxy_config)
	assert(proxy_result.ok and proxy_result.transforms.size() == 1)
	assert(proxy_result.transforms[0].origin.is_equal_approx(Vector3(3, 0, 0)))

	print("Scatter operation test passed: %d creator outputs, %d modified" % [creation_result.transforms.size(), modified.transforms.size()])
	target.free(); source.free(); quit(0)


func _make_target(node_name: String) -> MultiMeshInstance3D:
	var target := MultiMeshInstance3D.new(); target.name = node_name
	target.multimesh = MultiMesh.new(); target.multimesh.transform_format = MultiMesh.TRANSFORM_3D; target.multimesh.mesh = BoxMesh.new()
	return target
