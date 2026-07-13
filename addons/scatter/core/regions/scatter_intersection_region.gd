@tool
class_name ScatterIntersectionRegion
extends ScatterRegionValue

var a: ScatterShapeValue
var b: ScatterShapeValue


func _init(p_a: ScatterShapeValue = null, p_b: ScatterShapeValue = null) -> void:
	a = p_a if p_a != null else ScatterEmptyRegion.new()
	b = p_b if p_b != null else ScatterEmptyRegion.new()


func get_bounds_local() -> AABB:
	return ScatterMath.aabb_intersection(a.get_bounds_local(), b.get_bounds_local())


func contains_local(point: Vector3) -> bool:
	return a.contains_local(point) and b.contains_local(point)


func is_empty() -> bool:
	return a.is_empty() or b.is_empty() or get_bounds_local().size == Vector3.ZERO


func contains_exclusion(point: Vector3) -> bool:
	return a.contains_exclusion(point) or b.contains_exclusion(point)


func get_edges() -> Array[ScatterEdge]:
	var result: Array[ScatterEdge] = []
	if a is ScatterRegionValue:
		result.append_array((a as ScatterRegionValue).get_edges())
	if b is ScatterRegionValue:
		result.append_array((b as ScatterRegionValue).get_edges())
	return result
