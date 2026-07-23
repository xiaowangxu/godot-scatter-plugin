@tool
class_name ScatterTransformedShape
extends ScatterShapeValue

var source: ScatterShapeValue
var local_from_source := Transform3D.IDENTITY
var source_from_local := Transform3D.IDENTITY


func _init(p_source: ScatterShapeValue = null, p_local_from_source := Transform3D.IDENTITY) -> void:
	source = p_source if p_source != null else ScatterEmptyRegion.new()
	local_from_source = p_local_from_source
	source_from_local = local_from_source.affine_inverse()


func get_local_transform() -> Transform3D:
	return local_from_source * source.get_local_transform()


func get_intrinsic_dimension() -> int:
	return source.get_intrinsic_dimension()


func get_intrinsic_measure_local() -> float:
	return 0.0


func supports_direct_sampling() -> bool:
	return source.supports_direct_sampling()


func sample_local(value: float) -> Vector3:
	return local_from_source * source.sample_local(value)


func supports_neighbor_sampling() -> bool:
	return false


func get_bounds_local() -> AABB:
	var bounds := source.get_bounds_local()
	var corners := [
		bounds.position,
		bounds.position + Vector3(bounds.size.x, 0, 0),
		bounds.position + Vector3(0, bounds.size.y, 0),
		bounds.position + Vector3(0, 0, bounds.size.z),
		bounds.position + Vector3(bounds.size.x, bounds.size.y, 0),
		bounds.position + Vector3(bounds.size.x, 0, bounds.size.z),
		bounds.position + Vector3(0, bounds.size.y, bounds.size.z),
		bounds.end,
	]
	var result := AABB(local_from_source * corners[0], Vector3.ZERO)
	for corner in corners:
		result = result.expand(local_from_source * corner)
	return result


func contains_local(point: Vector3) -> bool:
	return source.contains_local(source_from_local * point)
