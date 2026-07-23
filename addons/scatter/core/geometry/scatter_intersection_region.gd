@tool
class_name ScatterIntersectionRegion
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
	return mini(a.get_intrinsic_dimension(), b.get_intrinsic_dimension())


func supports_direct_sampling() -> bool:
	return _sampling_source() != null


func supports_neighbor_sampling() -> bool:
	return false


func sample_local(value: float) -> Vector3:
	var source := _sampling_source()
	if source == null:
		return Vector3.INF
	var other := b if source == a else a
	for attempt in 64:
		var point := source.sample_local(ScatterSampleHash.dimension(value, attempt))
		if point.is_finite() and other.contains_local(point):
			return point
	return Vector3.INF


func get_bounds_local() -> AABB:
	return ScatterMath.aabb_intersection(a.get_bounds_local(), b.get_bounds_local())


func contains_local(point: Vector3) -> bool:
	return a.contains_local(point) and b.contains_local(point)


func is_empty() -> bool:
	return a.is_empty() or b.is_empty() or get_bounds_local().size == Vector3.ZERO


func get_edges() -> Array[ScatterEdge]:
	var result: Array[ScatterEdge] = []
	if a is ScatterRegionValue:
		result.append_array((a as ScatterRegionValue).get_edges())
	if b is ScatterRegionValue:
		result.append_array((b as ScatterRegionValue).get_edges())
	return result


func _sampling_source() -> ScatterShapeValue:
	var a_direct := a.supports_direct_sampling()
	var b_direct := b.supports_direct_sampling()
	if not a_direct and not b_direct:
		return null
	if a_direct and not b_direct:
		return a
	if b_direct and not a_direct:
		return b
	if a.get_intrinsic_dimension() != b.get_intrinsic_dimension():
		return a if a.get_intrinsic_dimension() < b.get_intrinsic_dimension() else b
	var measure_a := a.get_intrinsic_measure_local()
	var measure_b := b.get_intrinsic_measure_local()
	if measure_a <= 0.0:
		return b
	if measure_b <= 0.0:
		return a
	return a if measure_a <= measure_b else b
