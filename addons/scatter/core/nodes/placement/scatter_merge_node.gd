@tool
class_name ScatterMergeNode
extends ScatterPlacementNode


func get_type_id() -> StringName:
	return &"placement_merge"


func get_caption() -> String:
	return "Merge Placement"


func get_color() -> Color:
	return Color("9b70c9")


func get_input_ports() -> Array[ScatterPort]:
	return [
		ScatterPort.new(&"a", "A", ScatterPort.ValueType.INSTANCES),
		ScatterPort.new(&"b", "B", ScatterPort.ValueType.INSTANCES),
	]


func evaluate(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var a := inputs.instances(&"a")
	var b := inputs.instances(&"b")
	var result := a.duplicate_buffer() if a != null else ScatterInstanceBuffer.new()
	if b != null:
		result.append_buffer(b, context.maximum_instances)
	result.limit(context.maximum_instances)
	return result
