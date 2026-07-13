@tool
class_name ScatterUnionNode
extends ScatterRegionOperatorNode


func get_type_id() -> StringName:
	return &"region_union"


func get_caption() -> String:
	return "Union"


func get_color() -> Color:
	return Color("3fae9a")


func evaluate(_context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	return ScatterUnionRegion.new(inputs.region(&"a"), inputs.region(&"b"))
