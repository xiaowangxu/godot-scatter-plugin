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

	print("Scatter path extrude test passed")
	quit()
