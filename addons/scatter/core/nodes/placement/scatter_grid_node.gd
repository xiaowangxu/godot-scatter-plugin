@tool
class_name ScatterGridNode
extends ScatterPlacementSourceNode

@export var spacing := Vector3(2, 2, 2)


func get_input_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"shape", "Shape", ScatterValueTypeRegistry.SHAPE)]


func get_type_id() -> StringName:
	return &"create_grid"


func get_caption() -> String:
	return "Grid Placement"


func get_color() -> Color:
	return Color("4b9b72")


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterCreationOps.append_grid(buffer, inputs.shape(), spacing, context.maximum_instances)
	return buffer
