@tool
class_name ScatterGraphEvaluator
extends RefCounted


static func evaluate_node(
		graph: ScatterGraph,
		node_id: int,
		context: ScatterEvaluationContext,
		active: Dictionary[int, bool] = {},
) -> ScatterValue:
	if context.session.error != "":
		return null
	if active.has(node_id):
		context.session.error = "Scatter graph contains a cycle at node %d." % node_id
		return null
	var cache_key := context.evaluation_cache_key(node_id)
	if context.session.evaluation_cache.has(cache_key):
		context.session.evaluation_cache_hits += 1
		return _copy_cached_value(context.session.evaluation_cache[cache_key])
	var node := graph.find_node(node_id)
	if node == null:
		context.session.error = "Scatter graph references missing node %d." % node_id
		return null
	active[node_id] = true
	var inputs := ScatterNodeInputs.new()
	for port in node.get_input_ports():
		var input_context := node.prepare_input_context(port.id, context, inputs)
		for connection in graph.incoming_connections(node_id, port.id):
			var source_node := graph.find_node(connection.from_node_id)
			if source_node == null:
				context.session.error = "Scatter graph contains a dangling connection."
				active.erase(node_id)
				return null
			var output_port := source_node.output_port(connection.from_port_id)
			if output_port == null or output_port.value_type != port.value_type:
				context.session.error = "Scatter graph contains an incompatible connection."
				active.erase(node_id)
				return null
			var value := evaluate_node(graph, source_node.node_id, input_context, active.duplicate())
			if value == null:
				active.erase(node_id)
				return null
			inputs.add_value(port.id, value)
	var warnings := node.validate(context)
	if not warnings.is_empty():
		context.session.error = warnings[0]
		active.erase(node_id)
		return null
	var result := node.evaluate(context, inputs) if node.enabled or not node.can_disable() else node.evaluate_disabled(context, inputs)
	active.erase(node_id)
	if result == null:
		context.session.error = "Node %s returned no value." % node.get_caption()
	else:
		context.session.evaluation_cache[cache_key] = _copy_cached_value(result)
	return result


static func _copy_cached_value(value: ScatterValue) -> ScatterValue:
	if value is ScatterInstanceBuffer:
		return (value as ScatterInstanceBuffer).duplicate_buffer()
	if value is ScatterSetValue:
		var scatter_set := value as ScatterSetValue
		return ScatterSetValue.new(scatter_set.instances.duplicate_buffer(), scatter_set.source_group_id)
	# Region values are immutable evaluation products and can be shared safely.
	return value
