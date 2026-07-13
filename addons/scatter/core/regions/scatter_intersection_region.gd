@tool
class_name ScatterIntersectionRegion
extends ScatterRegionValue

var a: ScatterRegionValue
var b: ScatterRegionValue


func _init(p_a: ScatterRegionValue = null, p_b: ScatterRegionValue = null) -> void:
	a = p_a if p_a != null else ScatterEmptyRegion.new()
	b = p_b if p_b != null else ScatterEmptyRegion.new()


func get_bounds() -> AABB:
	return ScatterMath.aabb_intersection(a.get_bounds(), b.get_bounds())


func contains(point: Vector3) -> bool:
	return a.contains(point) and b.contains(point)


func is_empty() -> bool:
	return a.is_empty() or b.is_empty() or get_bounds().size == Vector3.ZERO


func contains_exclusion(point: Vector3) -> bool:
	return a.contains_exclusion(point) or b.contains_exclusion(point)


func get_edges() -> Array[ScatterEdge]:
	var result := a.get_edges()
	result.append_array(b.get_edges())
	return result


func sample(rng: RandomNumberGenerator, flat: bool) -> Vector3:
	var source := a if a.get_bounds().get_volume() <= b.get_bounds().get_volume() else b
	for _attempt in 100:
		var point := source.sample(rng, flat)
		if point.is_finite() and contains(point):
			return point
	return Vector3.INF
