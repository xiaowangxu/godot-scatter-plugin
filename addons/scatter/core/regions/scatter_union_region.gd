@tool
class_name ScatterUnionRegion
extends ScatterRegionValue

var a: ScatterShapeValue
var b: ScatterShapeValue


func _init(p_a: ScatterShapeValue = null, p_b: ScatterShapeValue = null) -> void:
	a = p_a if p_a != null else ScatterEmptyRegion.new()
	b = p_b if p_b != null else ScatterEmptyRegion.new()


func get_bounds_local() -> AABB:
	if a.is_empty():
		return b.get_bounds_local()
	if b.is_empty():
		return a.get_bounds_local()
	return a.get_bounds_local().merge(b.get_bounds_local())


func contains_local(point: Vector3) -> bool:
	return a.contains_local(point) or b.contains_local(point)


func is_empty() -> bool:
	return a.is_empty() and b.is_empty()


func contains_exclusion(point: Vector3) -> bool:
	return a.contains_exclusion(point) or b.contains_exclusion(point)


func get_edges() -> Array[ScatterEdge]:
	var result: Array[ScatterEdge] = []
	if a is ScatterRegionValue:
		result.append_array((a as ScatterRegionValue).get_edges())
	if b is ScatterRegionValue:
		result.append_array((b as ScatterRegionValue).get_edges())
	return result
