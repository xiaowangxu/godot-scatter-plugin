extends SceneTree


func _init() -> void:
	_test_types()
	_test_sampling()
	_test_boolean_pivots()
	_test_path_and_poisson()
	_test_shape_filtering()
	_test_grid_spaces()
	_test_spaces()
	print("Scatter node service test passed")
	quit()


func _test_types() -> void:
	ScatterValueTypeRegistry.ensure_builtins()
	assert(ScatterValueTypeRegistry.is_assignable(ScatterValueTypeRegistry.REGULAR_REGION, ScatterValueTypeRegistry.SHAPE))
	assert(ScatterValueTypeRegistry.is_assignable(ScatterValueTypeRegistry.REGULAR_REGION, ScatterValueTypeRegistry.DIRECT_SAMPLEABLE))
	assert(ScatterValueTypeRegistry.is_assignable(ScatterValueTypeRegistry.PATH, ScatterValueTypeRegistry.DIRECT_SAMPLEABLE))
	assert(ScatterValueTypeRegistry.is_assignable(ScatterValueTypeRegistry.PATH, ScatterValueTypeRegistry.SHAPE))
	assert(ScatterValueTypeRegistry.register_type(&"test_shape", [ScatterValueTypeRegistry.SHAPE], Color.WHITE))
	assert(ScatterValueTypeRegistry.is_assignable(&"test_shape", ScatterValueTypeRegistry.VALUE))
	assert(ScatterValueTypeRegistry.unregister_type(&"test_shape"))


func _test_sampling() -> void:
	var box := ScatterBoxRegion.new(Vector3.ZERO, Vector3(4, 2, 6))
	var sphere := ScatterSphereRegion.new(Vector3.ZERO, 3.0)
	for value in [0.0, 0.1, 0.5, 0.999]:
		assert(box.contains_local(box.sample_local(value)))
		assert(sphere.contains_local(sphere.sample_local(value)))
		assert(box.sample_local(value) == box.sample_local(value))
	var union := ScatterUnionRegion.new(
		ScatterBoxRegion.new(Vector3(-5, 0, 0), Vector3(2, 2, 2)),
		ScatterBoxRegion.new(Vector3(3, 0, 0), Vector3(6, 2, 2)),
	)
	var instances := ScatterInstances.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var result := ScatterCreationOps.append_random(instances, union, 8000, rng, 10000)
	assert(result.generated == 8000)
	var small := 0
	for transform in instances.transforms:
		if transform.origin.x < -3.0:
			small += 1
	var ratio := float(instances.transforms.size() - small) / float(small)
	assert(ratio > 2.6 and ratio < 3.4, "Union samples must follow volume, not child count")

	var transform_node := ScatterShapeTransformNode.new()
	transform_node.position = Vector3(7, 2, -3)
	transform_node.rotation = Vector3(0, 90, 0)
	transform_node.scale = Vector3(2, 1, 0.5)
	transform_node.set_dynamic_port_type(ScatterValueTypeRegistry.REGULAR_REGION)
	var transform_inputs := ScatterNodeInputs.new()
	var pivot_box := ScatterBoxRegion.new(Vector3(4, 1, -2), Vector3(4, 2, 6), Vector3(0, 30, 0))
	transform_inputs.add_value(&"geometry", pivot_box)
	var transformed_outputs := transform_node.evaluate(null, transform_inputs)
	var transformed_shape := transformed_outputs.get_value(&"geometry") as ScatterRegularRegionValue
	var shape_rotation := Basis.from_euler(transform_node.rotation * PI / 180.0)
	var shape_delta := Transform3D(
		shape_rotation.scaled_local(transform_node.scale),
		transform_node.position,
	)
	assert((shape_delta.basis * Vector3.RIGHT).is_equal_approx(shape_rotation * (Vector3.RIGHT * transform_node.scale)))
	assert(is_equal_approx((shape_delta.basis * Vector3.RIGHT).length(), 2.0))
	var source_frame := pivot_box.get_local_transform()
	var expected_transform := source_frame * shape_delta
	var expected_mapping := source_frame * shape_delta * source_frame.affine_inverse()
	assert(transformed_shape != null)
	assert(transformed_shape.get_local_transform().is_equal_approx(expected_transform))
	assert(transformed_shape.sample_local(0.37).is_equal_approx(expected_mapping * pivot_box.sample_local(0.37)))
	assert(transformed_shape.contains_local(expected_mapping * pivot_box.center))
	var chained_node := ScatterShapeTransformNode.new()
	chained_node.position = Vector3(-2, 4, 1)
	chained_node.rotation = Vector3(15, 0, 0)
	chained_node.set_dynamic_port_type(ScatterValueTypeRegistry.REGULAR_REGION)
	var chained_inputs := ScatterNodeInputs.new()
	chained_inputs.add_value(&"geometry", transformed_shape)
	var chained_shape := chained_node.evaluate(null, chained_inputs).get_value(&"geometry") as ScatterRegularRegionValue
	var chained_transform := Transform3D(
		Basis.from_euler(chained_node.rotation * PI / 180.0),
		chained_node.position,
	)
	var chained_mapping := expected_transform * chained_transform * expected_transform.affine_inverse()
	assert(chained_shape.get_local_transform().is_equal_approx(expected_transform * chained_transform))
	assert(chained_shape.sample_local(0.71).is_equal_approx(chained_mapping * expected_mapping * pivot_box.sample_local(0.71)))


func _test_boolean_pivots() -> void:
	var a := ScatterBoxRegion.new(Vector3(-4, 0, 0), Vector3(2, 2, 2), Vector3(0, 35, 0))
	var b := ScatterBoxRegion.new(Vector3(6, 0, 0), Vector3(2, 2, 2), Vector3(0, -20, 0))
	var union := ScatterUnionRegion.new(a, b)
	assert(union.get_local_transform().basis == Basis.IDENTITY)
	assert(union.get_local_transform().origin.is_equal_approx(union.get_bounds_local().get_center()))
	union.pivot_mode = ScatterRegionValue.BooleanPivot.FROM_A
	assert(union.get_local_transform().is_equal_approx(a.get_local_transform()))
	union.pivot_mode = ScatterRegionValue.BooleanPivot.FROM_B
	assert(union.get_local_transform().is_equal_approx(b.get_local_transform()))
	var intersection := ScatterIntersectionRegion.new(a, b)
	assert(intersection.get_local_transform().basis == Basis.IDENTITY)
	assert(intersection.get_local_transform().origin.is_equal_approx(intersection.get_bounds_local().get_center()))
	var subtract := ScatterSubtractRegion.new(a, b)
	assert(subtract.get_local_transform().is_equal_approx(a.get_local_transform()))
	assert(subtract.contains_local(Vector3(-4, 0, 0)))


func _test_path_and_poisson() -> void:
	var path := ScatterPathValue.new(PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0), Vector3(10, 0, 0)]))
	assert(path is ScatterShapeValue)
	assert(path.get_bounds_local().is_equal_approx(AABB(Vector3.ZERO, Vector3(10, 0, 0))))
	assert(path.contains_local(Vector3(4, 0, 0)))
	assert(not path.contains_local(Vector3(4, 0.01, 0)))
	assert(is_equal_approx(path.get_length_local(), 10.0))
	assert(path.sample_local(0.5).is_equal_approx(Vector3(5, 0, 0)))
	var path_transform := Transform3D(Basis.from_scale(Vector3(2, 1, 1)), Vector3(3, 0, 0))
	var transformed_path := path.transformed_local(path_transform)
	assert(transformed_path.get_script().resource_path.ends_with("scatter_transformed_path.gd"))
	assert(transformed_path.get_local_transform().is_equal_approx(path_transform))
	assert(is_equal_approx(transformed_path.get_length_local(), 20.0))
	assert(transformed_path.sample_local(0.5).is_equal_approx(Vector3(13, 0, 0)))
	assert(transformed_path.tangent_local(0.5).is_equal_approx(Vector3.RIGHT))
	var path_frame := Transform3D(Basis.from_euler(Vector3(0, PI * 0.25, 0)), Vector3(8, 2, -4))
	var framed_path := ScatterPathValue.new(PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 5)]), false, path_frame)
	var path_transform_node := ScatterShapeTransformNode.new()
	path_transform_node.position = Vector3(1, 0, 0)
	path_transform_node.rotation = Vector3(0, 30, 0)
	path_transform_node.set_dynamic_port_type(ScatterValueTypeRegistry.PATH)
	var path_inputs := ScatterNodeInputs.new()
	path_inputs.add_value(&"geometry", framed_path)
	var output_path := path_transform_node.evaluate(null, path_inputs).get_value(&"geometry") as ScatterPathValue
	var path_delta := Transform3D(Basis.from_euler(path_transform_node.rotation * PI / 180.0), path_transform_node.position)
	var path_mapping := path_frame * path_delta * path_frame.affine_inverse()
	assert(output_path.get_local_transform().is_equal_approx(path_frame * path_delta))
	assert(output_path.sample_local(0.63).is_equal_approx(path_mapping * framed_path.sample_local(0.63)))
	var random_path_instances := ScatterInstances.new()
	var path_rng := RandomNumberGenerator.new()
	path_rng.seed = 19
	var path_sampling := ScatterCreationOps.append_random(random_path_instances, path, 20, path_rng, 100)
	assert(path_sampling.generated == 20)
	for transform in random_path_instances.transforms:
		assert(path.contains_local(transform.origin))
	var path_poisson := ScatterInstances.new()
	ScatterCreationOps.append_poisson(path_poisson, path, 0.75, 15, 8, path_rng, 100)
	for index in path_poisson.transforms.size():
		assert(path.contains_local(path_poisson.transforms[index].origin))
		for other in range(index + 1, path_poisson.transforms.size()):
			assert(path_poisson.transforms[index].origin.distance_to(path_poisson.transforms[other].origin) >= 0.749)
	var poisson := ScatterInstances.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	ScatterCreationOps.append_poisson(poisson, ScatterBoxRegion.new(Vector3.ZERO, Vector3(8, 8, 8)), 1.0, 20, 150, rng, 1000)
	for index in poisson.transforms.size():
		for other in range(index + 1, poisson.transforms.size()):
			assert(poisson.transforms[index].origin.distance_to(poisson.transforms[other].origin) >= 0.999)


func _test_shape_filtering() -> void:
	var outer := ScatterBoxRegion.new(Vector3.ZERO, Vector3(10, 10, 10))
	var cutout := ScatterBoxRegion.new(Vector3.ZERO, Vector3(2, 2, 2))
	var shape := ScatterSubtractRegion.new(outer, cutout)
	var instances := ScatterInstances.new()
	instances.add_instance(Transform3D(Basis(), Vector3.ZERO), Color.RED, Color(1, 0, 0, 0))
	instances.add_instance(Transform3D(Basis(), Vector3(4, 0, 0)), Color.GREEN, Color(0, 1, 0, 0))
	instances.add_instance(Transform3D(Basis(), Vector3(8, 0, 0)), Color.BLUE, Color(0, 0, 1, 0))
	ScatterFilterOps.remove_outside(instances, shape)
	assert(instances.transforms.size() == 1)
	assert(instances.transforms[0].origin == Vector3(4, 0, 0))
	assert(instances.colors == [Color.GREEN])
	assert(instances.custom_data == [Color(0, 1, 0, 0)])


func _test_grid_spaces() -> void:
	var shape := ScatterBoxRegion.new(Vector3.ZERO, Vector3(4, 4, 4))
	var local_grid := ScatterInstances.new()
	ScatterCreationOps.append_grid(
		local_grid,
		shape,
		Vector3(2, 2, 2),
		Vector3.ZERO,
		Transform3D.IDENTITY,
		100,
	)
	assert(local_grid.transforms.size() == 27)
	assert(local_grid.transforms.any(func(value: Transform3D) -> bool: return value.origin == Vector3.ZERO))
	var offset_grid := ScatterInstances.new()
	ScatterCreationOps.append_grid(
		offset_grid,
		shape,
		Vector3(2, 2, 2),
		Vector3.ONE,
		Transform3D.IDENTITY,
		100,
	)
	assert(offset_grid.transforms.size() == 8)
	for transform in offset_grid.transforms:
		assert(is_equal_approx(absf(transform.origin.x), 1.0))
		assert(is_equal_approx(absf(transform.origin.y), 1.0))
		assert(is_equal_approx(absf(transform.origin.z), 1.0))
	var global_grid := ScatterInstances.new()
	ScatterCreationOps.append_grid(
		global_grid,
		shape,
		Vector3(2, 2, 2),
		Vector3.ZERO,
		Transform3D(Basis(), Vector3(-1, 0, 0)),
		100,
	)
	assert(global_grid.transforms.size() == 18)
	for transform in global_grid.transforms:
		assert(is_equal_approx(absf(transform.origin.x), 1.0))
	var instance_shape := ScatterBoxRegion.new(Vector3(5, 0, 0), Vector3(4, 0.2, 0.2), Vector3(0, 0, 90))
	var instance_grid := ScatterInstances.new()
	ScatterCreationOps.append_grid(
		instance_grid,
		instance_shape,
		Vector3(2, 1, 1),
		Vector3.ZERO,
		instance_shape.get_local_transform(),
		100,
	)
	assert(instance_grid.transforms.size() == 3)
	for transform in instance_grid.transforms:
		assert(is_equal_approx(transform.origin.x, 5.0))


func _test_spaces() -> void:
	var target := MultiMeshInstance3D.new()
	target.transform = Transform3D(Basis.from_euler(Vector3(0, PI * 0.5, 0)).scaled(Vector3(2, 1, 3)), Vector3(10, 0, 0))
	var buffer := ScatterInstances.new()
	buffer.add_instance(Transform3D.IDENTITY)
	ScatterTransformOps.apply_position(buffer, Vector3(1, 0, 0), 0, ScatterSpace.Type.GLOBAL, target)
	var global_delta := target.transform.basis * buffer.transforms[0].origin
	assert(global_delta.is_equal_approx(Vector3(1, 0, 0)))
	target.free()
