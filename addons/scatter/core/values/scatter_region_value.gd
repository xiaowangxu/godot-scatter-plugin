@tool
@abstract
class_name ScatterRegionValue
extends ScatterShapeValue


func get_value_type_id() -> StringName:
	return ScatterValueTypeRegistry.REGION


func contains_exclusion(_point: Vector3) -> bool:
	return false


func get_edges() -> Array[ScatterEdge]:
	return []
