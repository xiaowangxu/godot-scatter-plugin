extends SceneTree


func _init() -> void:
	var open_path := ScatterPathValue.new(PackedVector3Array([
		Vector3(-1, 1, -1),
		Vector3(1, 3, -1),
		Vector3(1, 5, 1),
		Vector3(-1, -1, 1),
	]), false)
	var region := ScatterPathExtrudeRegion.new(
		open_path,
		Vector3.UP,
		2.0,
		1.0,
		ScatterPathExtrudeRegion.Pivot.PROJECTED_CENTROID,
	)
	assert(not region.is_empty())
	assert(region.contains_local(Vector3(0, 2, 0)))
	assert(region.contains_local(Vector3(0, 4, 0)))
	assert(region.contains_local(Vector3(0, 1, 0)))
	assert(not region.contains_local(Vector3(0, 4.01, 0)))
	assert(not region.contains_local(Vector3(1.01, 2, 0)))
	assert(region.get_edges().size() == 12, "Open input paths must be force-closed for extrusion")
	assert(region.get_bounds_local().position.is_equal_approx(Vector3(-1, 1, -1)))
	assert(region.get_bounds_local().end.is_equal_approx(Vector3(1, 4, 1)))
	var centroid_frame := region.get_local_transform()
	assert(centroid_frame.origin.is_equal_approx(Vector3(0, 2, 0)))
	assert(centroid_frame.basis.y.is_equal_approx(Vector3.UP))
	assert(is_equal_approx(centroid_frame.basis.x.length(), 1.0))
	assert(is_equal_approx(centroid_frame.basis.y.length(), 1.0))
	assert(is_equal_approx(centroid_frame.basis.z.length(), 1.0))

	var path_frame := Transform3D(Basis.IDENTITY, Vector3(10, 5, 0))
	var offset_path := ScatterPathValue.new(PackedVector3Array([
		Vector3(1, 0, -1),
		Vector3(3, 0, -1),
		Vector3(3, 0, 1),
		Vector3(1, 0, 1),
	]), false, path_frame)
	var centroid_pivot := ScatterPathExtrudeRegion.new(
		offset_path,
		Vector3.UP,
		1.0,
		1.0,
		ScatterPathExtrudeRegion.Pivot.PROJECTED_CENTROID,
	)
	var origin_pivot := ScatterPathExtrudeRegion.new(
		offset_path,
		Vector3.UP,
		1.0,
		1.0,
		ScatterPathExtrudeRegion.Pivot.PROJECTED_PATH_ORIGIN,
	)
	assert(centroid_pivot.get_local_transform().origin.is_equal_approx(Vector3(12, 5, 0)))
	assert(origin_pivot.get_local_transform().origin.is_equal_approx(Vector3(10, 5, 0)))

	var tilted_normal := Vector3(1, 2, 3).normalized()
	var tilted := ScatterPathExtrudeRegion.new(offset_path, tilted_normal, 1.0, 1.0)
	assert(tilted.get_local_transform().basis.y.is_equal_approx(tilted_normal))

	var node := ScatterPathExtrudeNode.new()
	assert(node.get_input_ports()[0].type_id == ScatterValueTypeRegistry.PATH)
	assert(node.get_output_ports()[0].type_id == ScatterValueTypeRegistry.REGION)
	node.normal = Vector3.ZERO
	assert(not node.validate(null).is_empty())

	var closed_path := ScatterPathValue.new(PackedVector3Array([
		Vector3(-4, 0, -3),
		Vector3(4, 0, -3),
		Vector3(4, 0, 3),
		Vector3(-4, 0, 3),
	]), true)
	var planar := ScatterPlanarRegion.from_path(closed_path, Vector3.UP)
	assert(not planar.is_empty())
	assert(planar.get_intrinsic_dimension() == 2)
	assert(planar.contains_local(Vector3.ZERO))
	assert(not planar.contains_local(Vector3(5, 0, 0)))
	assert(not planar.contains_local(Vector3(0, 0.01, 0)))
	for value in [0.0, 0.13, 0.51, 0.999]:
		assert(planar.contains_local(planar.sample_local(value)))
	var planar_poisson := ScatterInstances.new()
	var planar_rng := RandomNumberGenerator.new()
	planar_rng.seed = 77
	ScatterCreationOps.append_poisson(
		planar_poisson,
		planar,
		0.65,
		20,
		100,
		planar_rng,
		1000,
	)
	assert(planar_poisson.transforms.size() >= 60)
	for index in planar_poisson.transforms.size():
		assert(planar.contains_local(planar_poisson.transforms[index].origin))
		for other in range(index + 1, planar_poisson.transforms.size()):
			assert(
				planar_poisson.transforms[index].origin.distance_to(
					planar_poisson.transforms[other].origin
				) >= 0.649
			)

	var planar_node := ScatterPathPlanarNode.new()
	assert(planar_node.get_input_ports()[0].type_id == ScatterValueTypeRegistry.PATH)
	assert(planar_node.get_output_ports()[0].type_id == ScatterValueTypeRegistry.PLANAR_REGION)
	var planar_inputs := ScatterNodeInputs.new()
	planar_inputs.add_value(&"path", closed_path)
	assert(planar_node.evaluate_value(null, planar_inputs) is ScatterPlanarRegion)
	var open_inputs := ScatterNodeInputs.new()
	open_inputs.add_value(&"path", open_path)
	assert((planar_node.evaluate_value(null, open_inputs) as ScatterPlanarRegion).is_empty())
	var diagnostic_session := ScatterEvaluationSession.new()
	var diagnostic_context := ScatterEvaluationContext.create(
		null,
		ScatterGraph.new(),
		diagnostic_session,
	)
	planar_node.evaluate_value(diagnostic_context, open_inputs)
	assert(diagnostic_session.diagnostics.size() == 1)
	assert(
		diagnostic_session.diagnostics[0].severity
		== ScatterDiagnostic.Severity.ERROR
	)
	assert(diagnostic_session.diagnostics[0].node_id == planar_node.node_id)

	var non_planar_path := ScatterPathValue.new(PackedVector3Array([
		Vector3(-1, 0, -1),
		Vector3(1, 0.1, -1),
		Vector3(1, 0, 1),
		Vector3(-1, 0, 1),
	]), true)
	assert(ScatterPlanarRegion.from_path(
		non_planar_path,
		Vector3.UP,
		ScatterPlanarRegion.PathOrigin.POLYGON_CENTROID,
		ScatterPlanarRegion.NonPlanarPolicy.REQUIRE_PLANAR,
		0.001,
	).is_empty())
	assert(not ScatterPlanarRegion.from_path(
		non_planar_path,
		Vector3.UP,
		ScatterPlanarRegion.PathOrigin.POLYGON_CENTROID,
		ScatterPlanarRegion.NonPlanarPolicy.PROJECT_TO_PLANE,
		0.001,
	).is_empty())

	var transform_node := ScatterShapeTransformNode.new()
	transform_node.position = Vector3(3, 2, -4)
	transform_node.rotation = Vector3(20, 35, 10)
	transform_node.scale = Vector3(2, 1, 0.5)
	transform_node.set_dynamic_port_type(ScatterValueTypeRegistry.PLANAR_REGION)
	var transform_inputs := ScatterNodeInputs.new()
	transform_inputs.add_value(&"geometry", planar)
	var transformed_planar := transform_node.evaluate(
		null,
		transform_inputs,
	).get_value(&"geometry") as ScatterShapeValue
	assert(transformed_planar.get_value_type_id() == ScatterValueTypeRegistry.PLANAR_REGION)
	assert(transformed_planar.get_intrinsic_dimension() == 2)
	assert(transformed_planar.supports_direct_sampling())
	for value in [0.17, 0.42, 0.83]:
		assert(transformed_planar.contains_local(transformed_planar.sample_local(value)))

	var cutout := ScatterPlanarRegion.new(
		PackedVector2Array([
			Vector2(-1, -1),
			Vector2(1, -1),
			Vector2(1, 1),
			Vector2(-1, 1),
		]),
		planar.frame,
	)
	var planar_with_hole := ScatterSubtractRegion.new(planar, cutout)
	assert(planar_with_hole.get_intrinsic_dimension() == 2)
	assert(planar_with_hole.supports_direct_sampling())
	for value in [0.03, 0.21, 0.64, 0.91]:
		var sample := planar_with_hole.sample_local(value)
		assert(sample.is_finite())
		assert(planar.contains_local(sample))
		assert(not cutout.contains_local(sample))

	print("Scatter path extrude test passed")
	quit()
