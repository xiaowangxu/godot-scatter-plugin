@tool
class_name ScatterTransformOps
extends RefCounted


static func apply_array(
		buffer: ScatterInstanceBuffer,
		amount: int,
		min_amount: int,
		local_offset: bool,
		offset: Vector3,
		local_rotation: bool,
		rotation_degrees: Vector3,
		individual_rotation_pivots: bool,
		rotation_pivot: Vector3,
		local_scale: bool,
		scale: Vector3,
		randomize_indices: bool,
		rng: RandomNumberGenerator,
		maximum: int,
) -> void:
	buffer.normalize()
	var originals := buffer.transforms.duplicate()
	var original_colors := buffer.colors.duplicate()
	var original_custom := buffer.custom_data.duplicate()
	amount = maxi(1, amount)
	for original_index in originals.size():
		var original: Transform3D = originals[original_index]
		var copy_count := rng.randi_range(maxi(0, min_amount), amount) if min_amount >= 0 else amount
		for copy_index in range(1, copy_count + 1):
			if buffer.transforms.size() >= maximum:
				return
			var copy := original
			var delta_basis := Basis.from_euler(rotation_degrees * PI / 180.0 * copy_index)
			copy.basis = copy.basis * delta_basis if local_rotation else delta_basis * copy.basis
			var scaled := ScatterMath.pow_vec3(scale, copy_index)
			copy.basis = (
				copy.basis.scaled(scaled)
				if local_scale
				else copy.basis.orthonormalized().scaled(copy.basis.get_scale() * scaled)
			)
			var move := offset * copy_index
			if local_offset:
				move = original.basis.orthonormalized() * move
			copy.origin += move
			var pivot := original.origin if individual_rotation_pivots else rotation_pivot
			copy.origin = pivot + delta_basis * (copy.origin - pivot)
			buffer.transforms.append(copy)
			buffer.colors.append(original_colors[original_index])
			buffer.custom_data.append(original_custom[original_index])
	if randomize_indices:
		for index in range(buffer.transforms.size() - 1, 0, -1):
			var swap_index := rng.randi_range(0, index)
			_swap_items(buffer.transforms, index, swap_index)
			_swap_items(buffer.colors, index, swap_index)
			_swap_items(buffer.custom_data, index, swap_index)


static func apply_transform(
		buffer: ScatterInstanceBuffer,
		position: Vector3,
		rotation_degrees: Vector3,
		scale: Vector3,
		space: int,
		target: Node3D,
) -> void:
	var delta := Transform3D(
		Basis.from_euler(rotation_degrees * PI / 180.0).scaled(scale),
		position,
	)
	for index in buffer.transforms.size():
		if space == 2:
			buffer.transforms[index] = buffer.transforms[index] * delta
		elif space == 0:
			buffer.transforms[index] = (
				target.global_transform.affine_inverse()
				* delta
				* target.global_transform
				* buffer.transforms[index]
			)
		else:
			buffer.transforms[index] = delta * buffer.transforms[index]


static func apply_position(
		buffer: ScatterInstanceBuffer,
		value: Vector3,
		operation: int,
		space: int,
		target: Node3D,
) -> void:
	if space == 0:
		value = target.global_transform.basis.inverse() * value
	for index in buffer.transforms.size():
		var transform := buffer.transforms[index]
		var resolved := transform.basis * value if space == 2 else value
		if operation == 0:
			transform.origin += resolved
		elif operation == 1:
			transform.origin *= resolved
		else:
			transform.origin = resolved
		buffer.transforms[index] = transform


static func apply_rotation(
		buffer: ScatterInstanceBuffer,
		value: Vector3,
		operation: int,
		space: int,
) -> void:
	var delta := Basis.from_euler(value * PI / 180.0)
	for index in buffer.transforms.size():
		var transform := buffer.transforms[index]
		if operation == 2:
			transform.basis = delta.scaled(transform.basis.get_scale())
		elif operation == 1:
			transform.basis = Basis.from_euler(transform.basis.get_euler() * value).scaled(transform.basis.get_scale())
		elif space == 2:
			transform.basis *= delta
		else:
			transform.basis = delta * transform.basis
		buffer.transforms[index] = transform


static func apply_scale(buffer: ScatterInstanceBuffer, value: Vector3, operation: int) -> void:
	for index in buffer.transforms.size():
		var transform := buffer.transforms[index]
		var current := transform.basis.get_scale()
		var next := current + value if operation == 0 else current * value if operation == 1 else value
		transform.basis = transform.basis.orthonormalized().scaled(next)
		buffer.transforms[index] = transform


static func apply_random_transform(
		buffer: ScatterInstanceBuffer,
		position: Vector3,
		rotation_degrees: Vector3,
		scale: Vector3,
		space: int,
		rng: RandomNumberGenerator,
		target: Node3D,
) -> void:
	for index in buffer.transforms.size():
		var transform := buffer.transforms[index]
		var offset := Vector3(
			rng.randf_range(-position.x, position.x),
			rng.randf_range(-position.y, position.y),
			rng.randf_range(-position.z, position.z),
		)
		if space == 2:
			offset = transform.basis.orthonormalized() * offset
		elif space == 0:
			offset = target.global_transform.basis.inverse() * offset
		transform.origin += offset
		var angles := Vector3(
			rng.randf_range(-rotation_degrees.x, rotation_degrees.x),
			rng.randf_range(-rotation_degrees.y, rotation_degrees.y),
			rng.randf_range(-rotation_degrees.z, rotation_degrees.z),
		) * PI / 180.0
		var delta := Basis.from_euler(angles)
		transform.basis = transform.basis * delta if space == 2 else delta * transform.basis
		var scale_delta := Vector3(
			1.0 + rng.randf_range(-scale.x, scale.x),
			1.0 + rng.randf_range(-scale.y, scale.y),
			1.0 + rng.randf_range(-scale.z, scale.z),
		)
		transform.basis = transform.basis.scaled(scale_delta)
		buffer.transforms[index] = transform


static func apply_random_rotation(
		buffer: ScatterInstanceBuffer,
		rotation_degrees: Vector3,
		snap_angle: Vector3,
		space: int,
		rng: RandomNumberGenerator,
) -> void:
	for index in buffer.transforms.size():
		var angles := Vector3(
			ScatterMath.random_snapped(rng, rotation_degrees.x, snap_angle.x),
			ScatterMath.random_snapped(rng, rotation_degrees.y, snap_angle.y),
			ScatterMath.random_snapped(rng, rotation_degrees.z, snap_angle.z),
		) * PI / 180.0
		var transform := buffer.transforms[index]
		var delta := Basis.from_euler(angles)
		transform.basis = transform.basis * delta if space == 2 else delta * transform.basis
		buffer.transforms[index] = transform


static func apply_look_at(buffer: ScatterInstanceBuffer, target_position: Vector3, up: Vector3) -> void:
	for index in buffer.transforms.size():
		var transform := buffer.transforms[index]
		var direction := target_position - transform.origin
		if direction.length_squared() > 0.000001:
			transform.basis = ScatterMath.basis_from_forward(direction.normalized(), up).scaled(transform.basis.get_scale())
		buffer.transforms[index] = transform


static func apply_snap(
		buffer: ScatterInstanceBuffer,
		position_step: Vector3,
		rotation_step_degrees: Vector3,
		scale_step: Vector3,
) -> void:
	var rotation_step := rotation_step_degrees * PI / 180.0
	for index in buffer.transforms.size():
		var transform := buffer.transforms[index]
		transform.origin = ScatterMath.snapped_vec3(transform.origin, position_step)
		var euler := ScatterMath.snapped_vec3(transform.basis.get_euler(), rotation_step)
		var scale := ScatterMath.snapped_vec3(transform.basis.get_scale(), scale_step)
		transform.basis = Basis.from_euler(euler).scaled(scale)
		buffer.transforms[index] = transform


static func apply_relax(
		buffer: ScatterInstanceBuffer,
		iterations: int,
		offset_step: float,
		consecutive_step_multiplier: float,
		restrict_height: bool,
) -> void:
	if buffer.transforms.size() < 2:
		return
	var offset := offset_step
	for _iteration in maxi(iterations, 0):
		var directions: Array[Vector3] = []
		for index in buffer.transforms.size():
			var closest := Vector3.ZERO
			var best := INF
			for other_index in buffer.transforms.size():
				if index == other_index:
					continue
				var difference := buffer.transforms[index].origin - buffer.transforms[other_index].origin
				if difference.length_squared() < best:
					best = difference.length_squared()
					closest = difference
			if restrict_height:
				closest.y = 0.0
			directions.append(closest.normalized() * offset)
		for index in buffer.transforms.size():
			buffer.transforms[index].origin += directions[index]
		offset *= consecutive_step_multiplier


static func apply_clusterize(
		buffer: ScatterInstanceBuffer,
		mask_path: String,
		mask_rotation_degrees: float,
		mask_offset: Vector2,
		mask_scale: Vector2,
		pixel_to_unit_ratio: float,
		remove_below: float,
		remove_above: float,
		scale_transforms: bool,
) -> void:
	if mask_path.is_empty() or not ResourceLoader.exists(mask_path):
		return
	var texture = ResourceLoader.load(mask_path)
	if not texture is Texture2D:
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return
	buffer.normalize()
	var angle := deg_to_rad(mask_rotation_degrees)
	var ratio := maxf(pixel_to_unit_ratio, 0.001)
	var safe_scale := Vector2(maxf(absf(mask_scale.x), 0.001), maxf(absf(mask_scale.y), 0.001))
	for index in range(buffer.transforms.size() - 1, -1, -1):
		var origin := buffer.transforms[index].origin
		var uv := Vector2(origin.x, origin.z) / ratio + Vector2(0.5, 0.5)
		uv = ((uv - Vector2(0.5, 0.5)).rotated(angle) / safe_scale) + Vector2(0.5, 0.5) + mask_offset
		var x := clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1)
		var y := clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1)
		var value := image.get_pixel(x, y).get_luminance()
		if value < remove_below or value > remove_above:
			buffer.remove_at(index)
		elif scale_transforms:
			buffer.transforms[index].basis = buffer.transforms[index].basis.scaled(Vector3.ONE * value)


static func apply_projection(
		buffer: ScatterInstanceBuffer,
		target: MultiMeshInstance3D,
		ray_direction: Vector3,
		ray_length: float,
		ray_offset: float,
		remove_points_on_miss: bool,
		align_with_collision_normal: bool,
		max_slope: float,
		collision_mask: int,
		exclude_mask: int,
) -> void:
	if not target.is_inside_tree() or target.get_world_3d() == null or ray_direction.length_squared() < 0.000001:
		return
	buffer.normalize()
	var state := target.get_world_3d().direct_space_state
	var direction := ray_direction.normalized()
	for index in range(buffer.transforms.size() - 1, -1, -1):
		var local_transform := buffer.transforms[index]
		var global_origin := target.to_global(local_transform.origin)
		var global_direction := (target.global_transform.basis * direction).normalized()
		var query := PhysicsRayQueryParameters3D.create(
			global_origin - global_direction * ray_offset,
			global_origin + global_direction * ray_length,
			collision_mask,
		)
		if exclude_mask != 0:
			var exclusion_query := PhysicsRayQueryParameters3D.create(query.from, query.to, exclude_mask)
			if not state.intersect_ray(exclusion_query).is_empty():
				buffer.remove_at(index)
				continue
		var hit := state.intersect_ray(query)
		if hit.is_empty():
			if remove_points_on_miss:
				buffer.remove_at(index)
			continue
		var normal: Vector3 = hit.normal
		if rad_to_deg(normal.angle_to(Vector3.UP)) > max_slope:
			buffer.remove_at(index)
			continue
		local_transform.origin = target.to_local(hit.position)
		if align_with_collision_normal:
			var local_normal := (target.global_transform.basis.inverse() * normal).normalized()
			local_transform.basis = ScatterMath.basis_from_up(local_normal, -local_transform.basis.z).scaled(local_transform.basis.get_scale())
		buffer.transforms[index] = local_transform


static func _swap_items(values: Array, a: int, b: int) -> void:
	var temporary = values[a]
	values[a] = values[b]
	values[b] = temporary
