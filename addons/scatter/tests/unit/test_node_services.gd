extends SceneTree


func _init() -> void:
	_test_types()
	_test_sampling()
	_test_path_and_poisson()
	_test_spaces()
	print("Scatter node service test passed")
	quit()


func _test_types() -> void:
	ScatterValueTypeRegistry.ensure_builtins()
	assert(ScatterValueTypeRegistry.is_assignable(ScatterValueTypeRegistry.REGULAR_REGION, ScatterValueTypeRegistry.SHAPE))
	assert(ScatterValueTypeRegistry.is_assignable(ScatterValueTypeRegistry.REGULAR_REGION, ScatterValueTypeRegistry.DIRECT_SAMPLEABLE))
	assert(ScatterValueTypeRegistry.is_assignable(ScatterValueTypeRegistry.PATH, ScatterValueTypeRegistry.DIRECT_SAMPLEABLE))
	assert(not ScatterValueTypeRegistry.is_assignable(ScatterValueTypeRegistry.PATH, ScatterValueTypeRegistry.SHAPE))
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


func _test_path_and_poisson() -> void:
	var path := ScatterPathValue.new(PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0), Vector3(10, 0, 0)]))
	assert(is_equal_approx(path.get_length_local(), 10.0))
	assert(path.sample_local(0.5).is_equal_approx(Vector3(5, 0, 0)))
	var path_transform := Transform3D(Basis.from_scale(Vector3(2, 1, 1)), Vector3(3, 0, 0))
	var transformed_path := path.transformed_local(path_transform)
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
	var poisson := ScatterInstances.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	ScatterCreationOps.append_poisson(poisson, ScatterBoxRegion.new(Vector3.ZERO, Vector3(8, 8, 8)), 1.0, 20, 150, rng, 1000)
	for index in poisson.transforms.size():
		for other in range(index + 1, poisson.transforms.size()):
			assert(poisson.transforms[index].origin.distance_to(poisson.transforms[other].origin) >= 0.999)


func _test_spaces() -> void:
	var target := MultiMeshInstance3D.new()
	target.transform = Transform3D(Basis.from_euler(Vector3(0, PI * 0.5, 0)).scaled(Vector3(2, 1, 3)), Vector3(10, 0, 0))
	var buffer := ScatterInstances.new()
	buffer.add_instance(Transform3D.IDENTITY)
	ScatterTransformOps.apply_position(buffer, Vector3(1, 0, 0), 0, ScatterSpace.Type.GLOBAL, target)
	var global_delta := target.transform.basis * buffer.transforms[0].origin
	assert(global_delta.is_equal_approx(Vector3(1, 0, 0)))
	target.free()
