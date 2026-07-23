@tool
class_name ScatterUnionRegion
extends ScatterRegionValue

var a: ScatterShapeValue
var b: ScatterShapeValue
var pivot_mode: int


func _init(
		p_a: ScatterShapeValue = null,
		p_b: ScatterShapeValue = null,
		p_pivot_mode := ScatterRegionValue.BooleanPivot.BOUNDS_CENTER,
) -> void:
	a = p_a if p_a != null else ScatterEmptyRegion.new()
	b = p_b if p_b != null else ScatterEmptyRegion.new()
	pivot_mode = p_pivot_mode


func get_local_transform() -> Transform3D:
	return ScatterRegionValue.resolve_boolean_pivot(pivot_mode, a, b, get_bounds_local())


func get_intrinsic_dimension() -> int:
	if a.get_intrinsic_dimension() == b.get_intrinsic_dimension():
		return a.get_intrinsic_dimension()
	return maxi(a.get_intrinsic_dimension(), b.get_intrinsic_dimension())


func get_intrinsic_measure_local() -> float:
	if a.get_intrinsic_dimension() != b.get_intrinsic_dimension():
		return 0.0
	return a.get_intrinsic_measure_local() + b.get_intrinsic_measure_local()


func supports_direct_sampling() -> bool:
	return (
		a.get_intrinsic_dimension() == b.get_intrinsic_dimension()
		and a.supports_direct_sampling()
		and b.supports_direct_sampling()
	)


func supports_neighbor_sampling() -> bool:
	return false


func sample_local(value: float) -> Vector3:
	if not supports_direct_sampling():
		return Vector3.INF
	var measure_a := maxf(a.get_intrinsic_measure_local(), 0.0)
	var measure_b := maxf(b.get_intrinsic_measure_local(), 0.0)
	var threshold := measure_a / (measure_a + measure_b) if measure_a + measure_b > 0.0 else 0.5
	for attempt in 32:
		var selector := ScatterSampleHash.dimension(value, attempt * 3)
		var source := a if selector < threshold else b
		var point := source.sample_local(ScatterSampleHash.dimension(value, attempt * 3 + 1))
		if not point.is_finite():
			continue
		if a.contains_local(point) and b.contains_local(point):
			if ScatterSampleHash.dimension(value, attempt * 3 + 2) >= 0.5:
				continue
		return point
	return Vector3.INF


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


func get_edges() -> Array[ScatterEdge]:
	var result: Array[ScatterEdge] = []
	if a is ScatterRegionValue:
		result.append_array((a as ScatterRegionValue).get_edges())
	if b is ScatterRegionValue:
		result.append_array((b as ScatterRegionValue).get_edges())
	return result
