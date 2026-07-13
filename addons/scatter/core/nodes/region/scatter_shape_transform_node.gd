@tool
class_name ScatterShapeTransformNode
extends ScatterNode

@export var position := Vector3.ZERO
@export var rotation := Vector3.ZERO
@export var scale := Vector3.ONE


func get_type_id() -> StringName:
	return &"shape_transform"


func get_caption() -> String:
	return "Shape Transform"


func get_category() -> StringName:
	return &"Shape"


func get_color() -> Color:
	return Color("5d83b3")


func get_input_ports() -> Array[ScatterPort]:
	return [
		ScatterPort.new(&"shape", "Shape", ScatterValueTypeRegistry.SHAPE),
		ScatterPort.new(&"path", "Path", ScatterValueTypeRegistry.PATH),
	]


func get_output_ports() -> Array[ScatterPort]:
	return [
		ScatterPort.new(&"shape", "Shape", ScatterValueTypeRegistry.SHAPE),
		ScatterPort.new(&"path", "Path", ScatterValueTypeRegistry.PATH),
	]


func evaluate(_context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterNodeOutputs:
	var outputs := ScatterNodeOutputs.new()
	var shape_transform := _transform()
	var shape := inputs.shape()
	var path := inputs.path()
	outputs.set_value(&"shape", _transform_shape(shape, shape_transform) if shape != null else ScatterEmptyRegion.new())
	outputs.set_value(&"path", _transform_path(path, shape_transform) if path != null else ScatterPathValue.new())
	return outputs


func evaluate_disabled(_context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterNodeOutputs:
	var outputs := ScatterNodeOutputs.new()
	outputs.set_value(&"shape", inputs.shape() if inputs.shape() != null else ScatterEmptyRegion.new())
	outputs.set_value(&"path", inputs.path() if inputs.path() != null else ScatterPathValue.new())
	return outputs


func evaluate_value(_context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var shape := inputs.shape()
	return _transform_shape(shape, _transform()) if shape != null else ScatterEmptyRegion.new()


func validate(_context: ScatterEvaluationContext) -> PackedStringArray:
	var errors := PackedStringArray()
	if absf(scale.x) <= 0.000001 or absf(scale.y) <= 0.000001 or absf(scale.z) <= 0.000001:
		errors.append("Shape Transform scale components must be non-zero.")
	return errors


func _transform() -> Transform3D:
	# Godot's Basis.scaled() left-multiplies (S * R), which scales in the
	# parent axes after rotation. Shape TRS uses the conventional local order
	# R * S, so points are scaled first and then rotated.
	return Transform3D(Basis.from_euler(rotation * PI / 180.0).scaled_local(scale), position)


static func _transform_shape(shape: ScatterShapeValue, transform: Transform3D) -> ScatterShapeValue:
	var frame := shape.get_local_transform()
	var local_mapping := frame * transform * frame.affine_inverse()
	if shape is ScatterRegularRegionValue:
		return ScatterTransformedRegularRegion.new(shape as ScatterRegularRegionValue, local_mapping)
	if shape is ScatterRegionValue:
		return ScatterTransformedRegion.new(shape as ScatterRegionValue, local_mapping)
	return ScatterTransformedShape.new(shape, local_mapping)


static func _transform_path(path: ScatterPathValue, transform: Transform3D) -> ScatterPathValue:
	var frame := path.get_local_transform()
	return path.transformed_local(frame * transform * frame.affine_inverse())
