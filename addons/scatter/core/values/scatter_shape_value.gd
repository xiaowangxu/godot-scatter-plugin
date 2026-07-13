@tool
@abstract
class_name ScatterShapeValue
extends ScatterValue


func get_value_type_id() -> StringName:
	return ScatterValueTypeRegistry.SHAPE


@abstract func get_bounds_local() -> AABB


@abstract func contains_local(point: Vector3) -> bool


func is_empty() -> bool:
	return get_bounds_local().size.is_zero_approx()
