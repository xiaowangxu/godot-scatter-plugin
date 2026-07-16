@tool
class_name ScatterGraphEvaluator
extends RefCounted


static func execute(plan: ScatterExecutionPlan, context: ScatterEvaluationContext) -> ScatterNodeOutputs:
	if plan == null or plan.has_errors():
		return null
	for node_id in plan.ordered_node_ids:
		if context.session.has_outputs(context, node_id):
			context.session.evaluation_cache_hits += 1
			var cached := context.session.get_outputs(context, node_id)
			var cached_node := plan.index.find_node(node_id)
			if cached == null or not _validate_outputs(cached_node, cached, context):
				return null
			_record_output_counts(cached_node, cached, context)
			continue
		var node := plan.index.find_node(node_id)
		var inputs := ScatterNodeInputs.new()
		for port in node.get_input_ports():
			for connection in plan.index.incoming_connections(node_id, port.id):
				var source_outputs := context.session.get_outputs(context, connection.from_node_id)
				var value := source_outputs.get_value(connection.from_port_id) if source_outputs != null else null
				if value == null:
					context.add_error(&"missing_runtime_output", node_id, "A connected source did not produce its declared output.", {"port": connection.from_port_id})
					return null
				inputs.add_value(port.id, value)
		for message in node.validate(context):
			context.add_error(&"node_validation", node_id, message)
		if _has_errors(context.session):
			return null
		var outputs := node.evaluate(context, inputs) if node.enabled or not node.can_disable() else node.evaluate_disabled(context, inputs)
		if outputs == null:
			context.add_error(&"null_outputs", node_id, "Node returned no output collection.")
			return null
		if not _validate_outputs(node, outputs, context):
			return null
		context.session.store_outputs(context, node_id, outputs)
		_record_output_counts(node, outputs, context)
	return context.session.get_outputs(context, plan.final_node_id)


static func evaluate_node(
		graph: ScatterGraph,
		node_id: int,
		context: ScatterEvaluationContext,
		_active: Dictionary[int, bool] = {},
) -> ScatterValue:
	var plan := ScatterGraphCompiler.compile(graph)
	for diagnostic in plan.diagnostics:
		context.session.diagnostics.append(diagnostic)
	if plan.has_errors():
		return null
	if execute(plan, context) == null:
		return null
	var node := graph.find_node(node_id)
	if node == null or node.get_output_ports().is_empty():
		return null
	var node_outputs := context.session.get_outputs(context, node_id)
	return node_outputs.get_value(node.get_output_ports()[0].id) if node_outputs != null else null


static func _validate_outputs(node: ScatterNode, outputs: ScatterNodeOutputs, context: ScatterEvaluationContext) -> bool:
	for port_id in outputs.port_ids():
		var declared := node.output_port(port_id)
		var value := outputs.get_value(port_id)
		if declared == null:
			context.add_error(&"undeclared_output", node.node_id, "Node produced an undeclared output.", {"port": port_id})
			return false
		if value == null or not ScatterValueTypeRegistry.is_assignable(value.get_value_type_id(), declared.type_id):
			context.add_error(&"runtime_output_type", node.node_id, "Node output has the wrong runtime type.", {"port": port_id, "actual": value.get_value_type_id() if value != null else &"null", "expected": declared.type_id})
			return false
	for port in node.get_output_ports():
		if not outputs.has_value(port.id):
			context.add_error(&"missing_declared_output", node.node_id, "Node did not produce a declared output.", {"port": port.id})
			return false
	return true


static func _record_output_counts(
		node: ScatterNode,
		outputs: ScatterNodeOutputs,
		context: ScatterEvaluationContext,
) -> void:
	for port in node.get_output_ports():
		var value := outputs.get_value(port.id)
		if value is ScatterInstances:
			context.session.set_output_count(context, node.node_id, port.id, (value as ScatterInstances).transforms.size())


static func _has_errors(session: ScatterEvaluationSession) -> bool:
	for diagnostic in session.diagnostics:
		if diagnostic.severity == ScatterDiagnostic.Severity.ERROR:
			return true
	return false
