@tool
class_name ScatterMultiMeshWriter
extends RefCounted


static func apply(target: MultiMeshInstance3D, result: ScatterBuildResult) -> void:
	if not is_instance_valid(target) or result == null or not result.ok:
		return
	var multimesh := target.multimesh
	if multimesh == null:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		target.multimesh = multimesh
	elif not multimesh.resource_local_to_scene and multimesh.get_reference_count() > 1:
		multimesh = multimesh.duplicate(true)
		target.multimesh = multimesh
	multimesh.resource_local_to_scene = true
	result.instances.normalize()
	multimesh.instance_count = 0
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.instance_count = result.instances.transforms.size()
	for index in result.instances.transforms.size():
		multimesh.set_instance_transform(index, result.instances.transforms[index])
		multimesh.set_instance_color(index, result.instances.colors[index])
		multimesh.set_instance_custom_data(index, result.instances.custom_data[index])
	multimesh.visible_instance_count = -1
	target.notify_property_list_changed()
