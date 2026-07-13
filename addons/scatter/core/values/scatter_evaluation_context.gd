@tool
class_name ScatterEvaluationContext
extends RefCounted

var target: MultiMeshInstance3D
var graph: ScatterGraph
var region: ScatterRegionValue
var session: ScatterEvaluationSession
var maximum_instances := 1_000_000


static func create(
		p_target: MultiMeshInstance3D,
		p_graph: ScatterGraph,
		p_session: ScatterEvaluationSession,
) -> ScatterEvaluationContext:
	var context := ScatterEvaluationContext.new()
	context.target = p_target
	context.graph = p_graph
	context.session = p_session
	return context


func with_region(value: ScatterRegionValue) -> ScatterEvaluationContext:
	var copy := ScatterEvaluationContext.create(target, graph, session)
	copy.region = value
	copy.maximum_instances = maximum_instances
	return copy


func with_target(p_target: MultiMeshInstance3D, p_graph: ScatterGraph) -> ScatterEvaluationContext:
	var copy := ScatterEvaluationContext.create(p_target, p_graph, session)
	copy.maximum_instances = maximum_instances
	return copy


func random_for(node: ScatterNode) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = node.custom_seed if node.override_seed else graph.seed ^ (node.node_id * 0x45d9f3b)
	return rng


func take_manual_instances() -> ScatterInstanceBuffer:
	var target_id := target.get_instance_id() if is_instance_valid(target) else 0
	if session.manual_claimed_targets.has(target_id):
		return ScatterInstanceBuffer.new()
	session.manual_claimed_targets[target_id] = true
	return graph.manual_instances.duplicate_buffer() if graph.manual_instances != null else ScatterInstanceBuffer.new()
