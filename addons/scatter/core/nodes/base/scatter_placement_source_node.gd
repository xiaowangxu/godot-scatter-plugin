@tool
@abstract
class_name ScatterPlacementSourceNode
extends ScatterPlacementNode


func get_input_ports() -> Array[ScatterPort]:
	return []


func source_only() -> bool:
	return true


func input_instances(context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterInstanceBuffer:
	return context.take_manual_instances()
