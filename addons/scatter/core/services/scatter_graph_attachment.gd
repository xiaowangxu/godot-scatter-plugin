@tool
class_name ScatterGraphAttachment
extends RefCounted

const META_KEY := &"_scatter_graph"


static func get_graph(target: MultiMeshInstance3D) -> ScatterGraph:
	if not is_instance_valid(target) or not target.has_meta(META_KEY):
		return null
	return target.get_meta(META_KEY) as ScatterGraph


static func get_or_create(target: MultiMeshInstance3D) -> ScatterGraph:
	var existing := get_graph(target)
	if existing != null:
		return existing
	var graph := ScatterGraphFactory.create_default()
	graph.resource_local_to_scene = true
	adopt_multimesh(target, graph)
	attach(target, graph)
	return graph


static func attach(target: MultiMeshInstance3D, graph: ScatterGraph) -> void:
	if not is_instance_valid(target) or graph == null:
		return
	graph.resource_local_to_scene = true
	target.set_meta(META_KEY, graph)
	target.notify_property_list_changed()


static func detach(target: MultiMeshInstance3D) -> void:
	if is_instance_valid(target) and target.has_meta(META_KEY):
		target.remove_meta(META_KEY)
		target.notify_property_list_changed()


static func adopt_multimesh(target: MultiMeshInstance3D, graph: ScatterGraph) -> void:
	if target.multimesh == null or graph == null:
		return
	for index in target.multimesh.instance_count:
		graph.manual_instances.transforms.append(target.multimesh.get_instance_transform(index))
		graph.manual_instances.colors.append(
			target.multimesh.get_instance_color(index) if target.multimesh.use_colors else Color.WHITE
		)
		graph.manual_instances.custom_data.append(
			target.multimesh.get_instance_custom_data(index)
			if target.multimesh.use_custom_data
			else Color(0, 0, 0, 0)
		)
