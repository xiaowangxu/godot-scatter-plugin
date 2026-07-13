@tool
class_name ScatterBoxNode
extends ScatterRegionNode

@export var center := Vector3.ZERO
@export var size := Vector3(10, 1, 10)
@export var rotation := Vector3.ZERO


func get_type_id() -> StringName:
	return &"shape_box"


func get_caption() -> String:
	return "Box Region"


func get_color() -> Color:
	return Color("5d83b3")


func evaluate(_context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterValue:
	return ScatterBoxRegion.new(center, size, rotation)


func get_preview_lines() -> PackedVector3Array:
	var result := PackedVector3Array()
	for edge in ScatterBoxRegion.new(center, size, rotation).get_edges():
		result.append(edge.a)
		result.append(edge.b)
	return result
