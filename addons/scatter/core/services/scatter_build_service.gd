@tool
class_name ScatterBuildService
extends RefCounted

const MAXIMUM_INSTANCES := 1_000_000


static func build_target(
		target: MultiMeshInstance3D,
		graph: ScatterGraph = null,
		session: ScatterEvaluationSession = null,
) -> ScatterBuildResult:
	if not is_instance_valid(target):
		return ScatterBuildResult.failure("Target is no longer valid.")
	if graph == null:
		graph = ScatterGraphAttachment.get_graph(target)
	if graph == null:
		return ScatterBuildResult.failure("Target has no Scatter graph.")
	if session == null:
		session = ScatterEvaluationSession.new()
	var target_id := target.get_instance_id()
	if session.visited_targets.has(target_id):
		return ScatterBuildResult.failure("Proxy cycle detected.")
	session.visited_targets[target_id] = true
	var final_output := graph.final_output_node()
	if final_output == null:
		session.visited_targets.erase(target_id)
		return ScatterBuildResult.failure("Scatter graph has no Final Output node.")
	var context := ScatterEvaluationContext.create(target, graph, session)
	context.maximum_instances = MAXIMUM_INSTANCES
	var value := ScatterGraphEvaluator.evaluate_node(graph, final_output.node_id, context)
	session.visited_targets.erase(target_id)
	if value == null or session.error != "":
		return ScatterBuildResult.failure(session.error if session.error != "" else "Scatter evaluation failed.")
	if not value is ScatterInstanceBuffer:
		return ScatterBuildResult.failure("Final Output did not produce instance data.")
	var result := ScatterBuildResult.new()
	result.instances = value
	result.instances.limit(MAXIMUM_INSTANCES)
	result.group_counts = session.group_counts.duplicate()
	return result
