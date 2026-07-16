@tool
@abstract
class_name ScatterEvaluationCache
extends RefCounted


@abstract func has_outputs(context: ScatterEvaluationContext, node_id: int) -> bool


@abstract func get_outputs(context: ScatterEvaluationContext, node_id: int) -> ScatterNodeOutputs


@abstract func store_outputs(context: ScatterEvaluationContext, node_id: int, outputs: ScatterNodeOutputs) -> void


func begin_execution(_execution_id: int) -> void:
	pass


@abstract func clear() -> void
