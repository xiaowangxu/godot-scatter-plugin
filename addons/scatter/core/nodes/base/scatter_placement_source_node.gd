@tool
@abstract
class_name ScatterPlacementSourceNode
extends ScatterPlacementNode


func get_input_ports() -> Array[ScatterPort]:
	return []


func input_instances(_context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterInstances:
	return ScatterInstances.new()
