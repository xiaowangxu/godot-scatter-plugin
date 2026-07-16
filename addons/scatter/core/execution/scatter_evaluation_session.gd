@tool
class_name ScatterEvaluationSession
extends RefCounted

var cache: ScatterEvaluationCache
var evaluation_cache_hits := 0
var diagnostics: Array[ScatterDiagnostic] = []
var execution_id := 0
var _output_counts: Dictionary = {}


func _init(p_cache: ScatterEvaluationCache = null) -> void:
	cache = p_cache if p_cache != null else ScatterMemoryEvaluationCache.new()


func begin_execution() -> void:
	execution_id += 1
	_output_counts.clear()
	if cache != null:
		cache.begin_execution(execution_id)


func has_outputs(context: ScatterEvaluationContext, node_id: int) -> bool:
	return cache != null and cache.has_outputs(context, node_id)


func get_outputs(context: ScatterEvaluationContext, node_id: int) -> ScatterNodeOutputs:
	return cache.get_outputs(context, node_id) if cache != null else null


func store_outputs(context: ScatterEvaluationContext, node_id: int, outputs: ScatterNodeOutputs) -> void:
	if cache != null:
		cache.store_outputs(context, node_id, outputs)


func set_output_count(context: ScatterEvaluationContext, node_id: int, port_id: StringName, count: int) -> void:
	var scope := context.cache_scope()
	if not _output_counts.has(scope):
		_output_counts[scope] = {}
	(_output_counts[scope] as Dictionary)["%d:%s" % [node_id, port_id]] = count


func output_counts_for(context: ScatterEvaluationContext) -> Dictionary:
	return (_output_counts.get(context.cache_scope(), {}) as Dictionary).duplicate()
