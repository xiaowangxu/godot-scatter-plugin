@tool
class_name ScatterSetValue
extends ScatterValue

var instances: ScatterInstanceBuffer
var source_group_id := 0


func _init(p_instances: ScatterInstanceBuffer = null, p_source_group_id := 0) -> void:
	instances = p_instances if p_instances != null else ScatterInstanceBuffer.new()
	source_group_id = p_source_group_id


func get_value_type() -> int:
	return ScatterPort.ValueType.SCATTER_SET
