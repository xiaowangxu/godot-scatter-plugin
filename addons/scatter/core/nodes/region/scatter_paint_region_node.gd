@tool
class_name ScatterPaintRegionNode
extends ScatterRegionNode

@export var strokes: Array[ScatterPaintStroke] = []
@export_range(0.01, 1000.0, 0.05) var depth := 0.35
@export_range(-1000.0, 1000.0, 0.01) var surface_offset := 0.0


func get_type_id() -> StringName:
	return &"paint_region"


func get_caption() -> String:
	return "Paint Region"


func get_color() -> Color:
	return Color("3fae9a")


func evaluate(_context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterValue:
	return ScatterPaintRegion.new(strokes, depth, surface_offset)


func get_preview_lines() -> PackedVector3Array:
	var result := PackedVector3Array()
	var step := maxi(1, ceili(float(strokes.size()) / 2500.0))
	for index in range(0, strokes.size(), step):
		var stroke := strokes[index]
		var normal := stroke.normal.normalized()
		var tangent := normal.cross(Vector3.FORWARD).normalized()
		if tangent.length_squared() < 0.001:
			tangent = normal.cross(Vector3.RIGHT).normalized()
		var bitangent := normal.cross(tangent).normalized()
		var center := stroke.position + normal * surface_offset
		for segment in 48:
			var angle_a := TAU * float(segment) / 48.0
			var angle_b := TAU * float(segment + 1) / 48.0
			result.append(center + tangent * cos(angle_a) * stroke.radius + bitangent * sin(angle_a) * stroke.radius)
			result.append(center + tangent * cos(angle_b) * stroke.radius + bitangent * sin(angle_b) * stroke.radius)
	return result
