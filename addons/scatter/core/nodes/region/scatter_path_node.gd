@tool
class_name ScatterPathNode
extends ScatterRegionNode

@export var points := PackedVector3Array([Vector3(-5, 0, 0), Vector3(5, 0, 0)])
@export_range(0.0, 1000000.0, 0.1) var thickness := 1.0
@export var closed := false


func get_type_id() -> StringName:
	return &"shape_path"


func get_caption() -> String:
	return "Path Region"


func get_color() -> Color:
	return Color("5d83b3")


func evaluate(_context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterValue:
	return ScatterPathRegion.new(points, thickness, closed)


func get_preview_lines() -> PackedVector3Array:
	var result := PackedVector3Array()
	for edge in ScatterPathRegion.new(points, thickness, closed).get_edges():
		result.append(edge.a)
		result.append(edge.b)
	return result
