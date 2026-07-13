@tool
class_name ScatterSubtractRegion
extends ScatterRegionValue

var a: ScatterRegionValue
var b: ScatterRegionValue


func _init(p_a: ScatterRegionValue = null, p_b: ScatterRegionValue = null) -> void:
	a = p_a if p_a != null else ScatterEmptyRegion.new()
	b = p_b if p_b != null else ScatterEmptyRegion.new()


func get_bounds() -> AABB:
	return a.get_bounds()


func contains(point: Vector3) -> bool:
	return a.contains(point) and not b.contains(point)


func is_empty() -> bool:
	return a.is_empty()


func contains_exclusion(point: Vector3) -> bool:
	return b.contains(point) or a.contains_exclusion(point)


func get_edges() -> Array[ScatterEdge]:
	return a.get_edges()


func sample(rng: RandomNumberGenerator, flat: bool) -> Vector3:
	for _attempt in 100:
		var point := a.sample(rng, flat)
		if point.is_finite() and not b.contains(point):
			return point
	return Vector3.INF
