@tool
class_name ScatterGraphCompiler
extends RefCounted


static func compile(graph: ScatterGraph) -> ScatterExecutionPlan:
	var plan := ScatterExecutionPlan.new()
	plan.graph = graph
	if graph == null:
		_add_error(plan, &"graph_missing", -1, "Scatter graph is missing.")
		return plan
	plan.index = ScatterGraphIndex.new(graph)
	var outputs: Array[ScatterNode] = []
	for node_id in plan.index.node_ids():
		var node := plan.index.find_node(node_id)
		if node.get_type_id() == &"final_output":
			outputs.append(node)
	if outputs.size() != 1:
		_add_error(plan, &"final_output_count", -1, "Scatter graph must contain exactly one Final Output node.", {"count": outputs.size()})
		return plan
	plan.final_node_id = outputs[0].node_id
	for node_id in plan.index.duplicate_node_ids:
		_add_error(plan, &"duplicate_node_id", node_id, "Scatter graph contains a duplicate node ID.")
	for connection in graph.connections:
		_validate_connection(plan.index, connection, plan)
	for node_id in plan.index.node_ids():
		var node := plan.index.find_node(node_id)
		for port in node.get_input_ports():
			if not port.variadic:
				continue
			var incoming := plan.index.incoming_connections(node.node_id, port.id)
			for index in incoming.size():
				if incoming[index].order != index:
					_add_error(plan, &"invalid_variadic_order", node.node_id, "Variadic connection order must be contiguous and unique.", {"port": port.id})
					break
	if plan.has_errors():
		return plan
	plan.topological_node_ids = _topological_order(plan.index)
	if plan.topological_node_ids.size() != plan.index.node_ids().size():
		_add_error(plan, &"cycle", -1, "Scatter graph contains a cycle.")
		return plan
	plan.ordered_node_ids = _reachable_order(plan.index, plan.final_node_id, plan.topological_node_ids)
	return plan


static func compile_node(graph: ScatterGraph, node_id: int) -> ScatterExecutionPlan:
	var plan := compile(graph)
	if plan.has_errors():
		return plan
	if plan.index.find_node(node_id) == null:
		_add_error(plan, &"missing_node", node_id, "Scatter graph references a missing node.")
		return plan
	plan.final_node_id = node_id
	plan.ordered_node_ids = _reachable_order(plan.index, node_id, plan.topological_node_ids)
	return plan


static func _topological_order(index: ScatterGraphIndex) -> Array[int]:
	var indegrees: Dictionary[int, int] = {}
	var pending: Array[int] = []
	for node_id in index.node_ids():
		indegrees[node_id] = index.incoming_connections(node_id).size()
		if indegrees[node_id] == 0:
			pending.append(node_id)
	var result: Array[int] = []
	var cursor := 0
	while cursor < pending.size():
		var node_id := pending[cursor]
		cursor += 1
		result.append(node_id)
		for connection in index.outgoing_connections(node_id):
			var target_id := connection.to_node_id
			indegrees[target_id] = indegrees[target_id] - 1
			if indegrees[target_id] == 0:
				pending.append(target_id)
	return result


static func _reachable_order(
		index: ScatterGraphIndex,
		target_id: int,
		topological_order: Array[int],
) -> Array[int]:
	var reachable: Dictionary[int, bool] = {}
	var pending: Array[int] = [target_id]
	var cursor := 0
	while cursor < pending.size():
		var node_id := pending[cursor]
		cursor += 1
		if reachable.has(node_id):
			continue
		reachable[node_id] = true
		for connection in index.incoming_connections(node_id):
			pending.append(connection.from_node_id)
	var result: Array[int] = []
	for node_id in topological_order:
		if reachable.has(node_id):
			result.append(node_id)
	return result


static func _validate_connection(index: ScatterGraphIndex, connection: ScatterConnection, plan: ScatterExecutionPlan) -> void:
	var source := index.find_node(connection.from_node_id)
	var target := index.find_node(connection.to_node_id)
	if source == null or target == null:
		_add_error(plan, &"dangling_node", connection.to_node_id, "Connection references a missing node.")
		return
	var output := source.output_port(connection.from_port_id)
	var input := target.input_port(connection.to_port_id)
	if output == null or input == null:
		_add_error(plan, &"dangling_port", target.node_id, "Connection references a missing port.", {"from_port": connection.from_port_id, "to_port": connection.to_port_id})
		return
	if not output.connectable or not input.connectable:
		_add_error(plan, &"hidden_port_connection", target.node_id, "Connection references a non-connectable port.")
	elif not ScatterValueTypeRegistry.is_assignable(output.type_id, input.type_id):
		_add_error(plan, &"incompatible_types", target.node_id, "Connection value types are incompatible.", {"actual": output.type_id, "expected": input.type_id})
	if not input.variadic and index.incoming_connections(target.node_id, input.id).size() > 1:
		_add_error(plan, &"multiple_non_variadic_inputs", target.node_id, "A non-variadic input has multiple connections.")


static func _add_error(plan: ScatterExecutionPlan, code: StringName, node_id: int, message: String, details := {}) -> void:
	plan.diagnostics.append(ScatterDiagnostic.new(ScatterDiagnostic.Severity.ERROR, code, node_id, message, details))
