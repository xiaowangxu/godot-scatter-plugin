@tool
class_name ScatterGridNode
extends ScatterPlacementSourceNode

@export var spacing := Vector3(2, 2, 2)
@export var restrict_height := true


func get_type_id() -> StringName:
	return &"create_grid"


func get_caption() -> String:
	return "Grid Placement"


func get_color() -> Color:
	return Color("4b9b72")


func evaluate(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterCreationOps.append_grid(buffer, context.region, spacing, restrict_height, context.maximum_instances)
	return buffer
