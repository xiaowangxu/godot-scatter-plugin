@tool
class_name ScatterCreationOps
extends RefCounted

const REJECTION_CAP := 8_000_000


static func append_random(
		buffer: ScatterInstances,
		shape: ScatterShapeValue,
		amount: int,
		rng: RandomNumberGenerator,
		maximum: int,
) -> Dictionary:
	var initial_size := buffer.transforms.size()
	var requested := mini(maxi(amount, 0), maxi(0, maximum - buffer.transforms.size()))
	var attempts := 0
	if shape == null or shape.is_empty() or requested == 0:
		return {"requested": requested, "generated": 0, "attempts": attempts}
	if shape.supports_direct_sampling():
		var budget := mini(REJECTION_CAP, maxi(256, requested * 32))
		while buffer.transforms.size() - initial_size < requested and attempts < budget:
			var point := shape.sample_local(rng.randf())
			attempts += 1
			if point.is_finite():
				buffer.add_instance(Transform3D(Basis(), point))
	else:
		var bounds := shape.get_bounds_local()
		var budget := mini(REJECTION_CAP, maxi(256, requested * 32))
		while buffer.transforms.size() < maximum and attempts < budget and requested > 0:
			var point := _random_in_bounds(bounds, rng)
			attempts += 1
			if shape.contains_local(point):
				buffer.add_instance(Transform3D(Basis(), point))
				requested -= 1
	var generated := buffer.transforms.size() - initial_size
	buffer.normalize()
	return {"requested": amount, "generated": generated, "attempts": attempts}


static func append_grid(
		buffer: ScatterInstances,
		shape: ScatterShapeValue,
		spacing: Vector3,
		offset: Vector3,
		grid_to_local: Transform3D,
		maximum: int,
) -> void:
	if shape == null or shape.is_empty():
		return
	if absf(grid_to_local.basis.determinant()) <= 0.000001:
		return
	spacing = ScatterMath.positive_vec3(spacing)
	var local_to_grid := grid_to_local.affine_inverse()
	var bounds := ScatterMath.transformed_aabb(shape.get_bounds_local(), local_to_grid)
	var x := _first_grid_coordinate(bounds.position.x, spacing.x, offset.x)
	while x <= bounds.end.x + 0.0001 and buffer.transforms.size() < maximum:
		var y := _first_grid_coordinate(bounds.position.y, spacing.y, offset.y)
		while y <= bounds.end.y + 0.0001 and buffer.transforms.size() < maximum:
			var z := _first_grid_coordinate(bounds.position.z, spacing.z, offset.z)
			while z <= bounds.end.z + 0.0001 and buffer.transforms.size() < maximum:
				var point := grid_to_local * Vector3(x, y, z)
				if shape.contains_local(point):
					buffer.add_instance(Transform3D(Basis(), point))
				z += spacing.z
			y += spacing.y
		x += spacing.x
	buffer.normalize()


static func _first_grid_coordinate(minimum: float, spacing: float, offset: float) -> float:
	return offset + ceilf((minimum - offset) / spacing - 0.000001) * spacing


static func append_poisson(
		buffer: ScatterInstances,
		shape: ScatterShapeValue,
		radius: float,
		candidates_per_active: int,
		max_points: int,
		rng: RandomNumberGenerator,
		maximum: int,
	) -> Dictionary:
	var requested := mini(maxi(max_points, 0), maxi(0, maximum - buffer.transforms.size()))
	var stats := {
		"requested": requested,
		"generated": 0,
		"attempts": 0,
		"local_attempts": 0,
		"global_attempts": 0,
		"budget_exhausted": false,
		"intrinsic_dimension": shape.get_intrinsic_dimension() if shape != null else 0,
	}
	if shape == null or shape.is_empty():
		return stats
	radius = maxf(radius, 0.001)
	var target_count := requested
	if target_count == 0:
		return stats
	var bounds := shape.get_bounds_local()
	var cell_size := radius / sqrt(3.0)
	var grid: Dictionary = {}
	var points: Array[Vector3] = []
	var active: Array[int] = []
	var attempt_budget := mini(
		REJECTION_CAP,
		maxi(2048, target_count * maxi(64, candidates_per_active * 8)),
	)
	var global_failure_limit := maxi(256, candidates_per_active * 16)
	var consecutive_global_failures := 0
	var initial := Vector3.INF
	while not initial.is_finite() and stats.attempts < mini(256, attempt_budget):
		initial = _sample_global(shape, bounds, rng)
		stats.attempts += 1
		stats.global_attempts += 1
	if not initial.is_finite():
		return stats
	points.append(initial)
	active.append(0)
	grid[_cell(initial, bounds.position, cell_size)] = 0
	while (
		points.size() < target_count
		and stats.attempts < attempt_budget
		and not (
			(active.is_empty() or not shape.supports_neighbor_sampling())
			and consecutive_global_failures >= global_failure_limit
		)
	):
		var use_global := (
			active.is_empty()
			or not shape.supports_neighbor_sampling()
			or rng.randf() < 0.15
		)
		if use_global:
			var global_candidate := _sample_global(shape, bounds, rng)
			stats.attempts += 1
			stats.global_attempts += 1
			if not global_candidate.is_finite():
				consecutive_global_failures += 1
				continue
			var global_cell := _cell(global_candidate, bounds.position, cell_size)
			if not _poisson_cell_valid(global_candidate, global_cell, points, grid, radius):
				consecutive_global_failures += 1
				continue
			points.append(global_candidate)
			active.append(points.size() - 1)
			grid[global_cell] = points.size() - 1
			consecutive_global_failures = 0
			continue
		var active_slot := rng.randi_range(0, active.size() - 1)
		var center := points[active[active_slot]]
		var accepted := false
		for _candidate_index in maxi(1, candidates_per_active):
			var candidate := shape.sample_neighbor_local(
				center,
				radius,
				radius * 2.0,
				rng.randf(),
			)
			stats.attempts += 1
			stats.local_attempts += 1
			if (
				not candidate.is_finite()
				or not bounds.has_point(candidate)
				or not shape.contains_local(candidate)
			):
				continue
			var cell := _cell(candidate, bounds.position, cell_size)
			if not _poisson_cell_valid(candidate, cell, points, grid, radius):
				continue
			points.append(candidate)
			active.append(points.size() - 1)
			grid[cell] = points.size() - 1
			accepted = true
			consecutive_global_failures = 0
			break
		if not accepted:
			active.remove_at(active_slot)
	for point in points:
		buffer.add_instance(Transform3D(Basis(), point))
	buffer.normalize()
	stats.generated = points.size()
	stats.budget_exhausted = stats.attempts >= attempt_budget and points.size() < target_count
	return stats


static func append_path_random(buffer: ScatterInstances, path: ScatterPathValue, count: int, align: bool, rng: RandomNumberGenerator, maximum: int) -> void:
	if path == null or path.get_length_local() <= 0.0:
		return
	for _index in mini(maxi(count, 0), maxi(0, maximum - buffer.transforms.size())):
		_append_path_transform(buffer, path, rng.randf(), align)
	buffer.normalize()


static func append_path_even(buffer: ScatterInstances, path: ScatterPathValue, spacing: float, offset: float, align: bool, maximum: int) -> void:
	if path == null or path.get_length_local() <= 0.0:
		return
	spacing = maxf(spacing, 0.001)
	var distance := maxf(offset, 0.0)
	while distance <= path.get_length_local() and buffer.transforms.size() < maximum:
		_append_path_transform(buffer, path, distance / path.get_length_local(), align)
		distance += spacing
	buffer.normalize()


static func append_path_continuous(buffer: ScatterInstances, path: ScatterPathValue, item_length: float, maximum: int) -> void:
	if path == null or path.get_length_local() <= 0.0:
		return
	var count := maxi(1, ceili(path.get_length_local() / maxf(item_length, 0.001)))
	for index in mini(count, maxi(0, maximum - buffer.transforms.size())):
		_append_path_transform(buffer, path, (float(index) + 0.5) / float(count), true)
	buffer.normalize()


static func append_single(buffer: ScatterInstances, offset: Vector3, rotation_degrees: Vector3, scale: Vector3, maximum: int) -> void:
	if buffer.transforms.size() >= maximum:
		return
	buffer.add_instance(Transform3D(Basis.from_euler(rotation_degrees * PI / 180.0).scaled(scale), offset))
	buffer.normalize()


static func _sample_global(
		shape: ScatterShapeValue,
		bounds: AABB,
		rng: RandomNumberGenerator,
	) -> Vector3:
	if shape.supports_direct_sampling():
		return shape.sample_local(rng.randf())
	var point := _random_in_bounds(bounds, rng)
	return point if shape.contains_local(point) else Vector3.INF


static func _random_in_bounds(bounds: AABB, rng: RandomNumberGenerator) -> Vector3:
	return Vector3(
		rng.randf_range(bounds.position.x, bounds.end.x),
		rng.randf_range(bounds.position.y, bounds.end.y),
		rng.randf_range(bounds.position.z, bounds.end.z),
	)


static func _cell(point: Vector3, origin: Vector3, cell_size: float) -> Vector3i:
	var relative := (point - origin) / cell_size
	return Vector3i(floori(relative.x), floori(relative.y), floori(relative.z))


static func _poisson_cell_valid(candidate: Vector3, cell: Vector3i, points: Array[Vector3], grid: Dictionary, radius: float) -> bool:
	for x in range(-2, 3):
		for y in range(-2, 3):
			for z in range(-2, 3):
				var neighbor := cell + Vector3i(x, y, z)
				if grid.has(neighbor) and candidate.distance_squared_to(points[int(grid[neighbor])]) < radius * radius:
					return false
	return true


static func _append_path_transform(buffer: ScatterInstances, path: ScatterPathValue, value: float, align: bool) -> void:
	var basis := Basis()
	if align:
		basis = ScatterMath.basis_from_forward(path.tangent_local(value), Vector3.UP)
	buffer.add_instance(Transform3D(basis, path.sample_local(value)))
