@tool
class_name ScatterMultiMeshWriter
extends RefCounted


static func apply(target: MultiMeshInstance3D, result: ScatterBuildResult) -> void:
	if not is_instance_valid(target) or result == null or not result.ok:
		return
	var multimesh := target.multimesh
	if _needs_replacement(multimesh):
		multimesh = _create_compatible_multimesh(multimesh)
		target.multimesh = multimesh
	else:
		# A compatible local resource only needs its allocation reset. Do not
		# redundantly assign format flags while it still owns instances.
		multimesh.instance_count = 0
	result.instances.normalize()
	multimesh.instance_count = result.instances.transforms.size()
	multimesh.buffer = _pack_buffer(result.instances)
	multimesh.visible_instance_count = -1
	target.notify_property_list_changed()


static func _needs_replacement(multimesh: MultiMesh) -> bool:
	return (
		multimesh == null
		or not multimesh.resource_local_to_scene
		or multimesh.transform_format != MultiMesh.TRANSFORM_3D
		or not multimesh.use_colors
		or not multimesh.use_custom_data
	)


static func _create_compatible_multimesh(source: MultiMesh) -> MultiMesh:
	var result := MultiMesh.new()
	result.resource_local_to_scene = true
	# These allocation-format properties must be configured before instance_count.
	result.transform_format = MultiMesh.TRANSFORM_3D
	result.use_colors = true
	result.use_custom_data = true
	if source != null:
		result.mesh = source.mesh
		result.custom_aabb = source.custom_aabb
		result.physics_interpolation_quality = source.physics_interpolation_quality
	return result


static func _pack_buffer(instances: ScatterInstances) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(instances.transforms.size() * 20)
	var cursor := 0
	for index in instances.transforms.size():
		var transform := instances.transforms[index]
		var color := instances.colors[index]
		var custom := instances.custom_data[index]
		buffer[cursor] = transform.basis.x.x
		buffer[cursor + 1] = transform.basis.y.x
		buffer[cursor + 2] = transform.basis.z.x
		buffer[cursor + 3] = transform.origin.x
		buffer[cursor + 4] = transform.basis.x.y
		buffer[cursor + 5] = transform.basis.y.y
		buffer[cursor + 6] = transform.basis.z.y
		buffer[cursor + 7] = transform.origin.y
		buffer[cursor + 8] = transform.basis.x.z
		buffer[cursor + 9] = transform.basis.y.z
		buffer[cursor + 10] = transform.basis.z.z
		buffer[cursor + 11] = transform.origin.z
		buffer[cursor + 12] = color.r
		buffer[cursor + 13] = color.g
		buffer[cursor + 14] = color.b
		buffer[cursor + 15] = color.a
		buffer[cursor + 16] = custom.r
		buffer[cursor + 17] = custom.g
		buffer[cursor + 18] = custom.b
		buffer[cursor + 19] = custom.a
		cursor += 20
	return buffer
