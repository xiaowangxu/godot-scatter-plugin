@tool
class_name ScatterTransformedPlanarRegion
extends ScatterRegionValue

var source: ScatterPlanarRegion
var local_from_source := Transform3D.IDENTITY
var source_from_local := Transform3D.IDENTITY


func _init(
		p_source: ScatterPlanarRegion = null,
		p_local_from_source := Transform3D.IDENTITY,
	) -> void:
	source = p_source if p_source != null else ScatterPlanarRegion.new()
	local_from_source = p_local_from_source
	source_from_local = local_from_source.affine_inverse()


func get_value_type_id() -> StringName:
	return ScatterValueTypeRegistry.PLANAR_REGION


func get_intrinsic_dimension() -> int:
	return 2


func get_intrinsic_measure_local() -> float:
	var source_frame := source.get_local_transform()
	var tangent_x := local_from_source.basis * source_frame.basis.x
	var tangent_z := local_from_source.basis * source_frame.basis.z
	return source.get_intrinsic_measure_local() * tangent_x.cross(tangent_z).length()


func supports_direct_sampling() -> bool:
	return true


func supports_neighbor_sampling() -> bool:
	return false


func get_local_transform() -> Transform3D:
	return local_from_source * source.get_local_transform()


func get_bounds_local() -> AABB:
	return ScatterMath.transformed_aabb(source.get_bounds_local(), local_from_source)


func contains_local(point: Vector3) -> bool:
	return source.contains_local(source_from_local * point)


func sample_local(value: float) -> Vector3:
	return local_from_source * source.sample_local(value)


func get_edges() -> Array[ScatterEdge]:
	var result: Array[ScatterEdge] = []
	for edge in source.get_edges():
		result.append(ScatterEdge.new(
			local_from_source * edge.a,
			local_from_source * edge.b,
		))
	return result
