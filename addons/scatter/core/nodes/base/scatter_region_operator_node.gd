@tool
@abstract
class_name ScatterRegionOperatorNode
extends ScatterRegionNode


func get_input_ports() -> Array[ScatterPort]:
	return [
		ScatterPort.new(&"a", "A", ScatterPort.ValueType.REGION),
		ScatterPort.new(&"b", "B", ScatterPort.ValueType.REGION),
	]
