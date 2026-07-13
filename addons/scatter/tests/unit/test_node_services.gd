extends SceneTree


func _init() -> void:
	_test_regions()
	_test_creation()
	_test_transforms_filters_and_data()
	_test_transform_spaces()
	_test_proxy_cycle()
	print("Scatter node service test passed")
	quit()


func _test_regions() -> void:
	var box := ScatterBoxRegion.new(Vector3.ZERO, Vector3(4, 2, 4), Vector3.ZERO)
	var sphere := ScatterSphereRegion.new(Vector3(2, 0, 0), 2.0)
	assert(box.contains(Vector3.ZERO))
	assert(not box.contains(Vector3(3, 0, 0)))
	assert(sphere.contains(Vector3(2, 0, 0)))
	var union := ScatterUnionRegion.new(box, sphere)
	var intersection := ScatterIntersectionRegion.new(box, sphere)
	var subtract := ScatterSubtractRegion.new(box, sphere)
	assert(union.contains(Vector3(3, 0, 0)))
	assert(intersection.contains(Vector3(1, 0, 0)))
	assert(not intersection.contains(Vector3(-1, 0, 0)))
	assert(subtract.contains(Vector3(-1, 0, 0)))
	assert(subtract.contains_exclusion(Vector3(1, 0, 0)))
	var strokes: Array[ScatterPaintStroke] = [ScatterPaintStroke.create(Vector3.ZERO, Vector3.UP, 2.0)]
	var paint := ScatterPaintRegion.new(strokes, 0.5, 0.25)
	assert(paint.contains(Vector3(1, 0.25, 0)))
	assert(not paint.contains(Vector3(3, 0.25, 0)))


func _test_creation() -> void:
	var region := ScatterBoxRegion.new(Vector3.ZERO, Vector3(10, 0.1, 10), Vector3.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var random_buffer := ScatterInstanceBuffer.new()
	ScatterCreationOps.append_random(random_buffer, region, 20, true, rng, 100)
	assert(random_buffer.transforms.size() == 20)
	for transform in random_buffer.transforms:
		assert(region.contains(transform.origin))
	var grid_buffer := ScatterInstanceBuffer.new()
	ScatterCreationOps.append_grid(grid_buffer, region, Vector3(5, 1, 5), true, 100)
	assert(grid_buffer.transforms.size() == 9)
	var poisson_buffer := ScatterInstanceBuffer.new()
	rng.seed = 21
	ScatterCreationOps.append_poisson(poisson_buffer, region, 1.0, 20, 30, true, rng, 100)
	assert(not poisson_buffer.transforms.is_empty())
	for a in poisson_buffer.transforms.size():
		for b in range(a + 1, poisson_buffer.transforms.size()):
			assert(poisson_buffer.transforms[a].origin.distance_to(poisson_buffer.transforms[b].origin) >= 0.999)
	var edge_buffer := ScatterInstanceBuffer.new()
	ScatterCreationOps.append_edges_even(edge_buffer, region, 2.0, 0.0, true, 100)
	assert(not edge_buffer.transforms.is_empty())


func _test_transforms_filters_and_data() -> void:
	var buffer := ScatterInstanceBuffer.new()
	buffer.transforms = [
		Transform3D(Basis(), Vector3(-1, 0, 0)),
		Transform3D(Basis(), Vector3(1, 0, 0)),
	]
	buffer.normalize()
	var transform_target := Node3D.new()
	ScatterTransformOps.apply_position(buffer, Vector3(1, 0, 0), 0, 1, transform_target)
	assert(buffer.transforms[0].origin == Vector3.ZERO)
	ScatterTransformOps.apply_scale(buffer, Vector3.ONE * 2.0, 1, ScatterTransformOps.Space.LOCAL, transform_target)
	assert(buffer.transforms[0].basis.get_scale().is_equal_approx(Vector3.ONE * 2.0))
	transform_target.free()
	ScatterTransformOps.apply_snap(buffer, Vector3.ONE, Vector3(90, 90, 90), Vector3.ONE)
	var region := ScatterBoxRegion.new(Vector3.ZERO, Vector3(2.1, 2.1, 2.1), Vector3.ZERO)
	ScatterFilterOps.remove_outside(buffer, region, false)
	assert(buffer.transforms.size() == 1)
	var colors: Array[Color] = []
	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = 8
	ScatterDataOps.randomize_colors(colors, 4, Color.BLACK, Color.WHITE, first_rng)
	var repeated: Array[Color] = []
	var second_rng := RandomNumberGenerator.new()
	second_rng.seed = 8
	ScatterDataOps.randomize_colors(repeated, 4, Color.BLACK, Color.WHITE, second_rng)
	assert(colors == repeated)
	var remove_rng := RandomNumberGenerator.new()
	ScatterFilterOps.remove_random(buffer, 100.0, remove_rng)
	assert(buffer.transforms.is_empty())


func _test_transform_spaces() -> void:
	var target := Node3D.new()
	var target_basis := Basis.from_euler(Vector3(0.0, PI * 0.5, 0.0))
	var target_transform := Transform3D(target_basis, Vector3(10.0, 3.0, -5.0))
	target.transform = target_transform

	var global_position := ScatterInstanceBuffer.new()
	global_position.transforms = [Transform3D.IDENTITY]
	ScatterTransformOps.apply_position(
		global_position,
		Vector3.RIGHT,
		0,
		ScatterTransformOps.Space.GLOBAL,
		target,
	)
	assert((target_transform * global_position.transforms[0].origin).is_equal_approx(target_transform.origin + Vector3.RIGHT))

	var local_position := ScatterInstanceBuffer.new()
	local_position.transforms = [Transform3D.IDENTITY]
	ScatterTransformOps.apply_position(
		local_position,
		Vector3.RIGHT,
		0,
		ScatterTransformOps.Space.LOCAL,
		target,
	)
	assert((target_transform * local_position.transforms[0].origin).is_equal_approx(target_transform.origin + target_basis * Vector3.RIGHT))

	var instance_position := ScatterInstanceBuffer.new()
	instance_position.transforms = [Transform3D(Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5)), Vector3.ZERO)]
	ScatterTransformOps.apply_position(
		instance_position,
		Vector3.RIGHT,
		0,
		ScatterTransformOps.Space.INSTANCE,
		target,
	)
	assert((target_transform * instance_position.transforms[0].origin).is_equal_approx(target_transform.origin + target_basis * Vector3.UP))
	ScatterTransformOps.apply_position(
		instance_position,
		Vector3.RIGHT * 3.0,
		2,
		ScatterTransformOps.Space.INSTANCE,
		target,
	)
	assert(instance_position.transforms[0].origin.is_equal_approx(Vector3.UP * 3.0))

	var rotation_delta := Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0))
	var global_rotation := ScatterInstanceBuffer.new()
	global_rotation.transforms = [Transform3D.IDENTITY]
	ScatterTransformOps.apply_rotation(
		global_rotation,
		Vector3(90.0, 0.0, 0.0),
		0,
		ScatterTransformOps.Space.GLOBAL,
		target,
	)
	assert(_basis_equal(target_basis * global_rotation.transforms[0].basis, rotation_delta * target_basis))

	var instance_rotation := ScatterInstanceBuffer.new()
	var initial_rotation := Basis.from_euler(Vector3(0.0, PI * 0.5, 0.0))
	instance_rotation.transforms = [Transform3D(initial_rotation, Vector3.ZERO)]
	ScatterTransformOps.apply_rotation(
		instance_rotation,
		Vector3(90.0, 0.0, 0.0),
		0,
		ScatterTransformOps.Space.INSTANCE,
		target,
	)
	assert(_basis_equal(instance_rotation.transforms[0].basis, initial_rotation * rotation_delta))

	var scale_delta := Basis.from_scale(Vector3(2.0, 1.0, 1.0))
	var initial_scale_rotation := Basis.from_euler(Vector3(0.0, PI * 0.25, 0.0))
	var instance_scale := ScatterInstanceBuffer.new()
	instance_scale.transforms = [Transform3D(initial_scale_rotation, Vector3.ZERO)]
	ScatterTransformOps.apply_scale(
		instance_scale,
		Vector3(2.0, 1.0, 1.0),
		1,
		ScatterTransformOps.Space.INSTANCE,
		target,
	)
	assert(_basis_equal(instance_scale.transforms[0].basis, initial_scale_rotation * scale_delta))

	var global_scale := ScatterInstanceBuffer.new()
	global_scale.transforms = [Transform3D(initial_scale_rotation, Vector3.ZERO)]
	ScatterTransformOps.apply_scale(
		global_scale,
		Vector3(2.0, 1.0, 1.0),
		1,
		ScatterTransformOps.Space.GLOBAL,
		target,
	)
	assert(_basis_equal(
		global_scale.transforms[0].basis,
		target_basis.inverse() * scale_delta * target_basis * initial_scale_rotation,
	))

	var combined := ScatterInstanceBuffer.new()
	combined.transforms = [Transform3D(initial_rotation, Vector3(2.0, 0.0, 0.0))]
	ScatterTransformOps.apply_transform(
		combined,
		Vector3.RIGHT,
		Vector3(90.0, 0.0, 0.0),
		Vector3(2.0, 1.0, 1.0),
		ScatterTransformOps.Space.GLOBAL,
		target,
	)
	assert((target_transform * combined.transforms[0].origin).is_equal_approx(target_transform * Vector3(2.0, 0.0, 0.0) + Vector3.RIGHT))
	assert(_basis_equal(
		target_basis * combined.transforms[0].basis,
		scale_delta * rotation_delta * target_basis * initial_rotation,
	))
	target.free()


func _basis_equal(a: Basis, b: Basis) -> bool:
	return a.x.is_equal_approx(b.x) and a.y.is_equal_approx(b.y) and a.z.is_equal_approx(b.z)


func _test_proxy_cycle() -> void:
	var owner := Node3D.new()
	root.add_child(owner)
	var a := MultiMeshInstance3D.new()
	a.name = "A"
	owner.add_child(a)
	var b := MultiMeshInstance3D.new()
	b.name = "B"
	owner.add_child(b)
	ScatterGraphAttachment.attach(a, _proxy_graph(NodePath("../B")))
	ScatterGraphAttachment.attach(b, _proxy_graph(NodePath("../A")))
	var result := ScatterBuildService.build_target(a)
	assert(not result.ok)
	assert(result.error.contains("cycle"))
	owner.free()


func _proxy_graph(path: NodePath) -> ScatterGraph:
	var graph := ScatterGraph.new()
	var box := ScatterBoxNode.new()
	var proxy := ScatterProxyNode.new()
	proxy.scatter_node = path
	var group := ScatterGroupNode.new()
	var output := ScatterFinalOutputNode.new()
	for node in [box, proxy, group, output]:
		graph.add_node(node)
	graph.connect_nodes(box.node_id, &"region", group.node_id, &"region")
	graph.connect_nodes(proxy.node_id, &"instances", group.node_id, &"placement")
	graph.connect_nodes(group.node_id, &"set", output.node_id, &"sets")
	return graph
