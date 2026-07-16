@tool
class_name ScatterProxyNode
extends ScatterPlacementSourceNode

@export var scatter_node := NodePath()
@export var auto_rebuild := true


func get_type_id() -> StringName:
	return &"proxy"


func get_caption() -> String:
	return "Proxy Graph"


func get_category() -> StringName:
	return &"Data"


func get_color() -> Color:
	return Color("8b929e")


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var buffer := input_instances(context, inputs)
	var source := context.target.get_node_or_null(scatter_node)
	if not source is MultiMeshInstance3D:
		return buffer
	var source_target := source as MultiMeshInstance3D
	var source_graph := context.resolver.resolve(source_target)
	if source_graph == null:
		return buffer
	var request := ScatterBuildRequest.create(source_target, source_graph, context.session, context.resolver)
	request.maximum_instances = context.maximum_instances
	request.backend = context.backend
	var result := (
		context.backend.generate(request)
		if context.backend != null
		else ScatterBuildService.generate(request)
	)
	if not result.ok:
		context.add_error(&"proxy_build_failed", node_id, result.error)
		return buffer
	var target_frame := context.target.global_transform if context.target.is_inside_tree() else context.target.transform
	var source_frame := source_target.global_transform if source_target.is_inside_tree() else source_target.transform
	var source_to_target: Transform3D = target_frame.affine_inverse() * source_frame
	var converted := ScatterInstances.new()
	for index in result.instances.transforms.size():
		converted.add_instance(
			source_to_target * result.instances.transforms[index],
			result.instances.colors[index],
			result.instances.custom_data[index],
		)
	buffer.append_instances(converted, context.maximum_instances)
	return buffer
