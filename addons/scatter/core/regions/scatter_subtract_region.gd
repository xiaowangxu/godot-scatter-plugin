@tool
class_name ScatterSubtractRegion
extends ScatterRegionValue

var a: ScatterShapeValue
var b: ScatterShapeValue


func _init(p_a: ScatterShapeValue = null, p_b: ScatterShapeValue = null) -> void:
	a = p_a if p_a != null else ScatterEmptyRegion.new()
	b = p_b if p_b != null else ScatterEmptyRegion.new()


func get_bounds_local() -> AABB:
	return a.get_bounds_local()


func contains_local(point: Vector3) -> bool:
	return a.contains_local(point) and not b.contains_local(point)


func is_empty() -> bool:
	return a.is_empty()


func contains_exclusion(point: Vector3) -> bool:
	return b.contains_local(point) or (a is ScatterRegionValue and (a as ScatterRegionValue).contains_exclusion(point))


func get_edges() -> Array[ScatterEdge]:
	return (a as ScatterRegionValue).get_edges() if a is ScatterRegionValue else []
