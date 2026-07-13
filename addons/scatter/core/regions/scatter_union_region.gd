@tool
class_name ScatterUnionRegion
extends ScatterRegionValue

var a: ScatterRegionValue
var b: ScatterRegionValue


func _init(p_a: ScatterRegionValue = null, p_b: ScatterRegionValue = null) -> void:
	a = p_a if p_a != null else ScatterEmptyRegion.new()
	b = p_b if p_b != null else ScatterEmptyRegion.new()


func get_bounds() -> AABB:
	if a.is_empty():
		return b.get_bounds()
	if b.is_empty():
		return a.get_bounds()
	return a.get_bounds().merge(b.get_bounds())


func contains(point: Vector3) -> bool:
	return a.contains(point) or b.contains(point)


func is_empty() -> bool:
	return a.is_empty() and b.is_empty()


func contains_exclusion(point: Vector3) -> bool:
	return a.contains_exclusion(point) or b.contains_exclusion(point)


func get_edges() -> Array[ScatterEdge]:
	var result := a.get_edges()
	result.append_array(b.get_edges())
	return result


func sample(rng: RandomNumberGenerator, flat: bool) -> Vector3:
	var first := a if rng.randf() < 0.5 else b
	var second := b if first == a else a
	var point := first.sample(rng, flat)
	return point if point.is_finite() else second.sample(rng, flat)
