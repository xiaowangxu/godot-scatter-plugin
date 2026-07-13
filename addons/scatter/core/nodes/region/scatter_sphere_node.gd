@tool
class_name ScatterSphereNode
extends ScatterRegionNode

@export var center := Vector3.ZERO
@export_range(0.001, 1000000.0, 0.1) var radius := 5.0


func get_type_id() -> StringName:
	return &"shape_sphere"


func get_caption() -> String:
	return "Sphere Region"


func get_color() -> Color:
	return Color("5d83b3")


func evaluate(_context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterValue:
	return ScatterSphereRegion.new(center, radius)


func get_preview_lines() -> PackedVector3Array:
	var result := PackedVector3Array()
	for edge in ScatterSphereRegion.new(center, radius).get_edges():
		result.append(edge.a)
		result.append(edge.b)
	return result
