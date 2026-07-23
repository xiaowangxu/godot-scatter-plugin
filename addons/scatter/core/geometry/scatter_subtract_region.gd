@tool
class_name ScatterSubtractRegion
extends ScatterRegionValue

var a: ScatterShapeValue
var b: ScatterShapeValue
var pivot_mode: int


func _init(
		p_a: ScatterShapeValue = null,
		p_b: ScatterShapeValue = null,
		p_pivot_mode := ScatterRegionValue.BooleanPivot.FROM_A,
) -> void:
	a = p_a if p_a != null else ScatterEmptyRegion.new()
	b = p_b if p_b != null else ScatterEmptyRegion.new()
	pivot_mode = p_pivot_mode


func get_local_transform() -> Transform3D:
	return ScatterRegionValue.resolve_boolean_pivot(pivot_mode, a, b, get_bounds_local())


func get_intrinsic_dimension() -> int:
	return a.get_intrinsic_dimension()


func supports_direct_sampling() -> bool:
	return a.supports_direct_sampling()


func supports_neighbor_sampling() -> bool:
	return false


func sample_local(value: float) -> Vector3:
	if not a.supports_direct_sampling():
		return Vector3.INF
	for attempt in 64:
		var point := a.sample_local(ScatterSampleHash.dimension(value, attempt))
		if point.is_finite() and not b.contains_local(point):
			return point
	return Vector3.INF


func get_bounds_local() -> AABB:
	return a.get_bounds_local()


func contains_local(point: Vector3) -> bool:
	return a.contains_local(point) and not b.contains_local(point)


func is_empty() -> bool:
	return a.is_empty()


func get_edges() -> Array[ScatterEdge]:
	return (a as ScatterRegionValue).get_edges() if a is ScatterRegionValue else []
