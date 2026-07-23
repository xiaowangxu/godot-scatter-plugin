@tool
class_name ScatterBoxRegion
extends ScatterRegularRegionValue

var center := Vector3.ZERO
var size := Vector3.ONE
var rotation_degrees := Vector3.ZERO


func _init(p_center := Vector3.ZERO, p_size := Vector3.ONE, p_rotation_degrees := Vector3.ZERO) -> void:
	center = p_center
	size = p_size
	rotation_degrees = p_rotation_degrees


func get_local_transform() -> Transform3D:
	return Transform3D(Basis.from_euler(rotation_degrees * PI / 180.0), center)


func get_intrinsic_dimension() -> int:
	var extent := ScatterMath.absolute_vec3(size)
	var dimension := 0
	for axis in 3:
		if extent[axis] > 0.000001:
			dimension += 1
	return dimension


func get_intrinsic_measure_local() -> float:
	var extent := ScatterMath.absolute_vec3(size)
	var measure := 1.0
	var dimension := 0
	for axis in 3:
		if extent[axis] > 0.000001:
			measure *= extent[axis]
			dimension += 1
	return measure if dimension > 0 else 0.0


func get_bounds_local() -> AABB:
	var corners := ScatterMath.box_corners(center, size, rotation_degrees)
	var result := AABB(corners[0], Vector3.ZERO)
	for corner in corners:
		result = result.expand(corner)
	return result


func contains_local(point: Vector3) -> bool:
	var half_size := ScatterMath.absolute_vec3(size) * 0.5
	var rotation := Basis.from_euler(rotation_degrees * PI / 180.0)
	var local := rotation.inverse() * (point - center)
	return (
		absf(local.x) <= half_size.x
		and absf(local.y) <= half_size.y
		and absf(local.z) <= half_size.z
	)


func sample_local(value: float) -> Vector3:
	var unit := Vector3(
		ScatterSampleHash.dimension(value, 0) - 0.5,
		ScatterSampleHash.dimension(value, 1) - 0.5,
		ScatterSampleHash.dimension(value, 2) - 0.5,
	)
	return center + Basis.from_euler(rotation_degrees * PI / 180.0) * (unit * ScatterMath.absolute_vec3(size))


func sample_neighbor_local(
		p_center: Vector3,
		minimum_distance: float,
		maximum_distance: float,
		value: float,
	) -> Vector3:
	var extent := ScatterMath.absolute_vec3(size)
	var rotation := Basis.from_euler(rotation_degrees * PI / 180.0)
	var local_center := rotation.inverse() * (p_center - center)
	var active_axes: Array[int] = []
	var thin_axes: Array[int] = []
	for axis in 3:
		if extent[axis] >= minimum_distance:
			active_axes.append(axis)
		else:
			thin_axes.append(axis)
	if active_axes.is_empty():
		return Vector3.INF
	var local_candidate := local_center
	var distance := lerpf(
		minimum_distance,
		maximum_distance,
		ScatterSampleHash.dimension(value, 0),
	)
	if active_axes.size() == 1:
		var direction := -1.0 if ScatterSampleHash.dimension(value, 1) < 0.5 else 1.0
		local_candidate[active_axes[0]] += direction * distance
	else:
		var angle := ScatterSampleHash.dimension(value, 1) * TAU
		if active_axes.size() == 2:
			local_candidate[active_axes[0]] += cos(angle) * distance
			local_candidate[active_axes[1]] += sin(angle) * distance
		else:
			var y := ScatterSampleHash.dimension(value, 2) * 2.0 - 1.0
			var planar := sqrt(maxf(0.0, 1.0 - y * y))
			local_candidate.x += cos(angle) * planar * distance
			local_candidate.y += y * distance
			local_candidate.z += sin(angle) * planar * distance
	for index in thin_axes.size():
		var axis := thin_axes[index]
		local_candidate[axis] = (
			ScatterSampleHash.dimension(value, 3 + index) - 0.5
		) * extent[axis]
	var candidate := center + rotation * local_candidate
	return candidate if contains_local(candidate) else Vector3.INF


func get_edges() -> Array[ScatterEdge]:
	var corners := ScatterMath.box_corners(center, size, rotation_degrees)
	var result: Array[ScatterEdge] = []
	for pair in [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7],
	]:
		result.append(ScatterEdge.new(corners[pair[0]], corners[pair[1]]))
	return result
