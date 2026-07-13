@tool
@abstract
class_name ScatterRegionValue
extends ScatterValue


func get_value_type() -> int:
	return ScatterPort.ValueType.REGION


@abstract func get_bounds() -> AABB


@abstract func contains(point: Vector3) -> bool


func is_empty() -> bool:
	return false


func contains_exclusion(_point: Vector3) -> bool:
	return false


func get_edges() -> Array[ScatterEdge]:
	return []


func sample(rng: RandomNumberGenerator, flat: bool) -> Vector3:
	if is_empty():
		return Vector3.INF
	var bounds := get_bounds()
	for _attempt in 100:
		var point := Vector3(
			rng.randf_range(bounds.position.x, bounds.end.x),
			bounds.get_center().y if flat else rng.randf_range(bounds.position.y, bounds.end.y),
			rng.randf_range(bounds.position.z, bounds.end.z),
		)
		if contains(point):
			return point
	return Vector3.INF
