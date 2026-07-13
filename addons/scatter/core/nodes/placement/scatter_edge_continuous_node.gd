@tool
class_name ScatterEdgeContinuousNode
extends ScatterPlacementSourceNode

@export_range(0.001, 1000000.0, 0.1) var item_length := 2.0
@export var ignore_slopes := false


func get_type_id() -> StringName:
	return &"edge_continuous"


func get_caption() -> String:
	return "Along Edge Continuous"


func get_color() -> Color:
	return Color("4b9b72")


func evaluate(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterCreationOps.append_edges_continuous(
		buffer,
		context.region,
		item_length,
		ignore_slopes,
		context.maximum_instances,
	)
	return buffer
