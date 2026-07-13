@tool
@abstract
class_name ScatterRegionNode
extends ScatterNode


func get_category() -> StringName:
	return &"Region"


func get_input_ports() -> Array[ScatterPort]:
	return []


func get_output_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"region", "Region", ScatterPort.ValueType.REGION)]


func evaluate_disabled(_context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterValue:
	return ScatterEmptyRegion.new()
