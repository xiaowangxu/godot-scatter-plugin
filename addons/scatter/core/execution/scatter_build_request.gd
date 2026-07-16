@tool
class_name ScatterBuildRequest
extends RefCounted

var target: MultiMeshInstance3D
var graph: ScatterGraph
var session: ScatterEvaluationSession
var maximum_instances := 1_000_000


static func create(
		p_target: MultiMeshInstance3D,
		p_graph: ScatterGraph = null,
		p_session: ScatterEvaluationSession = null,
) -> ScatterBuildRequest:
	var request := ScatterBuildRequest.new()
	request.target = p_target
	request.graph = p_graph
	request.session = p_session if p_session != null else ScatterEvaluationSession.new()
	return request
