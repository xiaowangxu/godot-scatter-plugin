@tool
class_name ScatterBuildService
extends RefCounted

const MAXIMUM_INSTANCES := 1_000_000


static func build_target(
		target: MultiMeshInstance3D,
		graph: ScatterGraph = null,
		session: ScatterEvaluationSession = null,
) -> ScatterBuildResult:
	var request := ScatterBuildRequest.create(target, graph, session)
	request.maximum_instances = MAXIMUM_INSTANCES
	return generate(request)


static func generate(request: ScatterBuildRequest) -> ScatterBuildResult:
	if request == null:
		return ScatterBuildResult.failure("Build request is missing.")
	var session := request.session if request.session != null else ScatterEvaluationSession.new()
	request.session = session
	var diagnostic_start := session.diagnostics.size()
	var target := request.target
	if not is_instance_valid(target):
		return _failure(session, diagnostic_start, &"target_invalid", "Target is no longer valid.")
	var graph := request.graph
	if graph == null:
		graph = ScatterGraphAttachment.get_graph(target)
		request.graph = graph
	if graph == null:
		return _failure(session, diagnostic_start, &"graph_missing", "Target has no Scatter graph.")
	session.begin_execution()
	var context := ScatterEvaluationContext.create(target, graph, session)
	context.maximum_instances = request.maximum_instances
	var plan := ScatterGraphCompiler.compile(graph)
	for diagnostic in plan.diagnostics:
		session.diagnostics.append(diagnostic)
	var outputs := ScatterGraphEvaluator.execute(plan, context) if not plan.has_errors() else null
	var result := _result_with_diagnostics(session, diagnostic_start)
	if outputs == null or not result.errors.is_empty():
		result.ok = false
		result.error = result.errors[0].message if not result.errors.is_empty() else "Scatter evaluation failed."
		return result
	var value := outputs.get_value(&"result")
	if not value is ScatterInstances:
		return _failure(session, diagnostic_start, &"invalid_final_output", "Final Output did not produce instance data.")
	# Cache entries are owned by the evaluation session. The public result is a
	# build-boundary copy so presentation or callers cannot mutate cached output.
	result.instances = (value as ScatterInstances).duplicate_instances()
	result.instances.limit(request.maximum_instances)
	result.output_counts = session.output_counts_for(context)
	return result


static func _failure(
		session: ScatterEvaluationSession,
		diagnostic_start: int,
		code: StringName,
		message: String,
) -> ScatterBuildResult:
	session.diagnostics.append(ScatterDiagnostic.new(ScatterDiagnostic.Severity.ERROR, code, -1, message))
	var result := _result_with_diagnostics(session, diagnostic_start)
	result.ok = false
	result.error = message
	return result


static func _result_with_diagnostics(session: ScatterEvaluationSession, start: int) -> ScatterBuildResult:
	var result := ScatterBuildResult.new()
	for index in range(start, session.diagnostics.size()):
		var diagnostic := session.diagnostics[index]
		if diagnostic.severity == ScatterDiagnostic.Severity.ERROR:
			result.errors.append(diagnostic)
		else:
			result.warnings.append(diagnostic)
	return result
