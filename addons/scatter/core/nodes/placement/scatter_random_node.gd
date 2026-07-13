@tool
class_name ScatterRandomNode
extends ScatterPlacementSourceNode

@export_range(0, 1000000, 1) var amount := 100
@export var restrict_height := true


func get_type_id() -> StringName:
	return &"create_random"


func get_caption() -> String:
	return "Random Placement"


func get_color() -> Color:
	return Color("4b9b72")


func supports_seed() -> bool:
	return true


func evaluate(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterCreationOps.append_random(
		buffer,
		context.region,
		amount,
		restrict_height,
		context.random_for(self),
		context.maximum_instances,
	)
	return buffer
