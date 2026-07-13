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
	multimesh.buffer = _pack_buffer(result.instances)
	multimesh.visible_instance_count = -1
	target.notify_property_list_changed()


static func _pack_buffer(instances: ScatterInstances) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(instances.transforms.size() * 20)
	var cursor := 0
	for index in instances.transforms.size():
		var transform := instances.transforms[index]
		var color := instances.colors[index]
		var custom := instances.custom_data[index]
		for value in [
			transform.basis.x.x, transform.basis.y.x, transform.basis.z.x, transform.origin.x,
			transform.basis.x.y, transform.basis.y.y, transform.basis.z.y, transform.origin.y,
			transform.basis.x.z, transform.basis.y.z, transform.basis.z.z, transform.origin.z,
			color.r, color.g, color.b, color.a,
			custom.r, custom.g, custom.b, custom.a,
		]:
			buffer[cursor] = value
			cursor += 1
	return buffer
