@tool
class_name ScatterFinalOutputNode
extends ScatterNode


func get_type_id() -> StringName:
	return &"final_output"


func get_caption() -> String:
	return "Final Output"


func get_category() -> StringName:
	return &"Group"


func get_color() -> Color:
	return Color("d9aa56")


func get_input_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"sets", "Scatter Sets", ScatterPort.ValueType.SCATTER_SET, true)]


func get_output_ports() -> Array[ScatterPort]:
	return []


func evaluate(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var combined := ScatterInstanceBuffer.new()
	var sets := inputs.scatter_sets(&"sets")
	for scatter_set in sets:
		combined.append_buffer(scatter_set.instances, context.maximum_instances)
		if combined.transforms.size() >= context.maximum_instances:
			break
	combined.normalize()
	return combined


func can_disable() -> bool:
	return false


func is_deletable() -> bool:
	return false
