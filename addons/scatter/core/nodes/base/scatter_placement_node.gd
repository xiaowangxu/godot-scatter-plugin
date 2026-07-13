@tool
@abstract
class_name ScatterPlacementNode
extends ScatterNode


func get_category() -> StringName:
	return &"Placement"


func get_input_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"instances", "Instances", ScatterPort.ValueType.INSTANCES)]


func get_output_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"instances", "Instances", ScatterPort.ValueType.INSTANCES)]


func source_only() -> bool:
	return false


func input_instances(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterInstanceBuffer:
	var value := inputs.instances()
	return value.duplicate_buffer() if value != null else context.take_manual_instances()


func evaluate_disabled(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	return input_instances(context, inputs)
