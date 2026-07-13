@tool
class_name ScatterEdgeEvenNode
extends ScatterPlacementSourceNode

@export_range(0.001, 1000000.0, 0.1) var spacing := 1.0
@export var offset := 0.0
@export var align_to_path := false


func get_type_id() -> StringName:
	return &"edge_even"


func get_caption() -> String:
	return "Along Edge Even"


func get_color() -> Color:
	return Color("4b9b72")


func evaluate(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterCreationOps.append_edges_even(
		buffer,
		context.region,
		spacing,
		offset,
		align_to_path,
		context.maximum_instances,
	)
	return buffer
