@tool
@abstract
class_name ScatterShapeValue
extends ScatterValue


func get_value_type_id() -> StringName:
	return ScatterValueTypeRegistry.SHAPE


## Maps the shape's own coordinate system into MultiMesh Local space.
## Composite shapes that no longer have a single source coordinate system use
## identity and continue to implement their queries directly in Local space.
func get_local_transform() -> Transform3D:
	return Transform3D.IDENTITY


func shape_to_local(point: Vector3) -> Vector3:
	return get_local_transform() * point


func local_to_shape(point: Vector3) -> Vector3:
	return get_local_transform().affine_inverse() * point


## Returns the geometric dimension in which the shape is authored.
## Volumes are 3D, planar regions are 2D, and paths are 1D.
func get_intrinsic_dimension() -> int:
	return 3


func get_intrinsic_measure_local() -> float:
	return 0.0


## Direct sampling avoids rejection against the shape AABB. Implementations
## must distribute values over the shape's intrinsic measure (length, area,
## or volume), rather than over its child count or parameterization.
func supports_direct_sampling() -> bool:
	return false


func sample_local(_value: float) -> Vector3:
	return Vector3.INF


## Neighbor proposals are optional. Poisson placement falls back to global
## proposals when a shape cannot efficiently sample a local annulus.
func supports_neighbor_sampling() -> bool:
	return true


func sample_neighbor_local(
		center: Vector3,
		minimum_distance: float,
		maximum_distance: float,
		value: float,
	) -> Vector3:
	var y := ScatterSampleHash.dimension(value, 0) * 2.0 - 1.0
	var angle := ScatterSampleHash.dimension(value, 1) * TAU
	var planar := sqrt(maxf(0.0, 1.0 - y * y))
	var direction := Vector3(cos(angle) * planar, y, sin(angle) * planar)
	var distance := lerpf(minimum_distance, maximum_distance, ScatterSampleHash.dimension(value, 2))
	return center + direction * distance


@abstract func get_bounds_local() -> AABB


@abstract func contains_local(point: Vector3) -> bool


func is_empty() -> bool:
	return get_bounds_local().size.is_zero_approx()
