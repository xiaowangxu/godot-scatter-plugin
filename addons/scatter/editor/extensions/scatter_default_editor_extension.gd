@tool
class_name ScatterDefaultEditorExtension
extends ScatterNodeEditorExtension


func draw_gizmo(context: ScatterNodeEditorContext, sink: ScatterGizmoSink) -> void:
	if context == null or context.node == null:
		return
	var ports := context.node.get_output_ports()
	if ports.is_empty():
		return
	var value := _selected_value(context)
	if value is ScatterRegionValue:
		var lines := PackedVector3Array()
		for edge in (value as ScatterRegionValue).get_edges():
			lines.append(edge.a)
			lines.append(edge.b)
		sink.add_lines(lines)
	elif value is ScatterInstances:
		var lines := PackedVector3Array()
		var instances := value as ScatterInstances
		var amount := mini(2000, instances.transforms.size())
		for index in amount:
			var transform := instances.transforms[index]
			var radius := 0.12
			lines.append(transform.origin - transform.basis.x.normalized() * radius)
			lines.append(transform.origin + transform.basis.x.normalized() * radius)
			lines.append(transform.origin - transform.basis.y.normalized() * radius)
			lines.append(transform.origin + transform.basis.y.normalized() * radius)
			lines.append(transform.origin - transform.basis.z.normalized() * radius)
			lines.append(transform.origin + transform.basis.z.normalized() * radius)
		sink.add_lines(lines, &"instances")


func _selected_value(context: ScatterNodeEditorContext) -> ScatterValue:
	var plan := ScatterGraphCompiler.compile(context.graph)
	if not plan.has_errors():
		var session := ScatterEvaluationSession.new()
		var evaluation := ScatterEvaluationContext.create(context.target, context.graph, session)
		ScatterGraphEvaluator.execute(plan, evaluation)
		var outputs: ScatterNodeOutputs = session.evaluation_cache.get(evaluation.cache_key(context.node.node_id))
		if outputs != null and not context.node.get_output_ports().is_empty():
			return outputs.get_value(context.node.get_output_ports()[0].id)
	# Disconnected source nodes can still provide a useful standalone preview.
	if context.node.get_input_ports().is_empty():
		var evaluation := ScatterEvaluationContext.create(context.target, context.graph, ScatterEvaluationSession.new())
		return context.node.evaluate_value(evaluation, ScatterNodeInputs.new())
	return null
