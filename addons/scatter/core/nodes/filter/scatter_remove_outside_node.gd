@tool
class_name ScatterRemoveOutsideNode
extends ScatterPlacementNode

@export var negative_shapes_only := false


func get_type_id() -> StringName:
	return &"remove_outside"


func get_caption() -> String:
	return "Remove Outside"


func get_category() -> StringName:
	return &"Filter"


func get_color() -> Color:
	return Color("bd5b60")


func evaluate(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	ScatterFilterOps.remove_outside(buffer, context.region, negative_shapes_only)
	return buffer
