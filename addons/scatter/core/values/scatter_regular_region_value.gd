@tool
@abstract
class_name ScatterRegularRegionValue
extends ScatterRegionValue


func get_value_type_id() -> StringName:
	return ScatterValueTypeRegistry.REGULAR_REGION


func supports_direct_sampling() -> bool:
	return true


@abstract func sample_local(value: float) -> Vector3
