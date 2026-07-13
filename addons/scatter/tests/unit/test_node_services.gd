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


func _test_path_and_poisson() -> void:
	var path := ScatterPathValue.new(PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0), Vector3(10, 0, 0)]))
	assert(is_equal_approx(path.get_length_local(), 10.0))
	assert(path.sample_local(0.5).is_equal_approx(Vector3(5, 0, 0)))
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
