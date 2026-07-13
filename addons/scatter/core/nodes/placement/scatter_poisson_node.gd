@tool
class_name ScatterPoissonNode
extends ScatterPlacementSourceNode

@export_range(0.001, 1000000.0, 0.05) var radius := 1.0
@export_range(1, 100, 1) var samples_before_rejection := 15
@export_range(1, 1000000, 1) var max_points := 10000
@export var restrict_height := true


func get_type_id() -> StringName:
	return &"create_poisson"


func get_caption() -> String:
	return "Poisson Placement"


func get_color() -> Color:
	return Color("4b9b72")


func supports_seed() -> bool:
	return true


func evaluate(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterCreationOps.append_poisson(
		buffer,
		context.region,
		radius,
		samples_before_rejection,
		max_points,
		restrict_height,
		context.random_for(self),
		context.maximum_instances,
	)
	return buffer
