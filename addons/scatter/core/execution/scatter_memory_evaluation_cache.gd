@tool
class_name ScatterMemoryEvaluationCache
extends ScatterEvaluationCache

var _entries: Dictionary[String, ScatterNodeOutputs] = {}


func has_outputs(context: ScatterEvaluationContext, node_id: int) -> bool:
	return context != null and _entries.has(context.ephemeral_cache_key(node_id))


func get_outputs(context: ScatterEvaluationContext, node_id: int) -> ScatterNodeOutputs:
	return _entries.get(context.ephemeral_cache_key(node_id)) if context != null else null


func store_outputs(context: ScatterEvaluationContext, node_id: int, outputs: ScatterNodeOutputs) -> void:
	if context != null and outputs != null:
		_entries[context.ephemeral_cache_key(node_id)] = outputs


func begin_execution(_execution_id: int) -> void:
	clear()


func clear() -> void:
	_entries.clear()
