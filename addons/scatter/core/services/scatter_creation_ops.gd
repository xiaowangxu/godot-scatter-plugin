@tool
class_name ScatterCreationOps
extends RefCounted


static func append_random(
		buffer: ScatterInstanceBuffer,
		region: ScatterRegionValue,
		amount: int,
		restrict_height: bool,
		rng: RandomNumberGenerator,
		maximum: int,
) -> void:
	if region == null:
		region = ScatterEmptyRegion.new()
	for _index in mini(maxi(amount, 0), maxi(0, maximum - buffer.transforms.size())):
		var point := region.sample(rng, restrict_height)
		if not point.is_finite():
			break
		buffer.transforms.append(Transform3D(Basis(), point))
	buffer.normalize()


static func append_grid(
		buffer: ScatterInstanceBuffer,
		region: ScatterRegionValue,
		spacing: Vector3,
		restrict_height: bool,
		maximum: int,
) -> void:
	if region == null or region.is_empty():
		return
	spacing = ScatterMath.positive_vec3(spacing)
	var bounds := region.get_bounds()
	var y_values: Array[float] = [bounds.get_center().y]
	if not restrict_height:
		y_values.clear()
		var y := bounds.position.y
		while y <= bounds.end.y + 0.0001:
			y_values.append(y)
			y += spacing.y
	var x := bounds.position.x
	while x <= bounds.end.x + 0.0001 and buffer.transforms.size() < maximum:
		for y in y_values:
			var z := bounds.position.z
			while z <= bounds.end.z + 0.0001 and buffer.transforms.size() < maximum:
				var point := Vector3(x, y, z)
				if region.contains(point):
					buffer.transforms.append(Transform3D(Basis(), point))
				z += spacing.z
		x += spacing.x
	buffer.normalize()


static func append_poisson(
		buffer: ScatterInstanceBuffer,
		region: ScatterRegionValue,
		radius: float,
		samples_before_rejection: int,
		max_points: int,
		restrict_height: bool,
		rng: RandomNumberGenerator,
		maximum: int,
) -> void:
	if region == null or region.is_empty():
		return
	radius = maxf(radius, 0.001)
	max_points = mini(maxi(max_points, 0), maxi(0, maximum - buffer.transforms.size()))
	var rejection := maxi(samples_before_rejection, 1)
	var points: Array[Vector3] = []
	var grid: Dictionary = {}
	var bounds := region.get_bounds()
	var cell_size := radius / sqrt(2.0 if restrict_height else 3.0)
	var failed := 0
	while points.size() < max_points and failed < rejection * maxi(20, points.size()):
		var candidate := region.sample(rng, restrict_height)
		if not candidate.is_finite() or not region.contains(candidate):
			failed += 1
			continue
		var relative := (candidate - bounds.position) / cell_size
		var cell := Vector3i(
			floori(relative.x),
			0 if restrict_height else floori(relative.y),
			floori(relative.z),
		)
		if _poisson_cell_valid(candidate, cell, grid, radius, restrict_height):
			points.append(candidate)
			var bucket: Array = grid.get(cell, [])
			bucket.append(candidate)
			grid[cell] = bucket
			failed = 0
		else:
			failed += 1
	for point in points:
		buffer.transforms.append(Transform3D(Basis(), point))
	buffer.normalize()


static func append_edges_random(
		buffer: ScatterInstanceBuffer,
		region: ScatterRegionValue,
		instance_count: int,
		align_to_path: bool,
		rng: RandomNumberGenerator,
		maximum: int,
) -> void:
	var edges := region.get_edges() if region != null else []
	if edges.is_empty():
		return
	var first_new := buffer.transforms.size()
	var amount := mini(maxi(instance_count, 0), maxi(0, maximum - first_new))
	for _index in amount:
		var edge: ScatterEdge = edges[rng.randi_range(0, edges.size() - 1)]
		_append_edge_transform(buffer, edge, rng.randf(), align_to_path)
	_remove_new_outside(buffer, first_new, region)
	buffer.normalize()


static func append_edges_even(
		buffer: ScatterInstanceBuffer,
		region: ScatterRegionValue,
		spacing: float,
		offset: float,
		align_to_path: bool,
		maximum: int,
) -> void:
	spacing = maxf(spacing, 0.001)
	var first_new := buffer.transforms.size()
	for edge in region.get_edges() if region != null else []:
		var length: float = edge.a.distance_to(edge.b)
		var distance := offset
		while distance <= length and buffer.transforms.size() < maximum:
			_append_edge_transform(
				buffer,
				edge,
				clampf(distance / maxf(length, 0.0001), 0.0, 1.0),
				align_to_path,
			)
			distance += spacing
	_remove_new_outside(buffer, first_new, region)
	buffer.normalize()


static func append_edges_continuous(
		buffer: ScatterInstanceBuffer,
		region: ScatterRegionValue,
		item_length: float,
		_ignore_slopes: bool,
		maximum: int,
) -> void:
	item_length = maxf(item_length, 0.001)
	var first_new := buffer.transforms.size()
	for edge in region.get_edges() if region != null else []:
		var length: float = edge.a.distance_to(edge.b)
		var count := maxi(1, ceili(length / item_length))
		for index in count:
			if buffer.transforms.size() >= maximum:
				break
			_append_edge_transform(buffer, edge, (float(index) + 0.5) / count, true)
	_remove_new_outside(buffer, first_new, region)
	buffer.normalize()


static func append_single(
		buffer: ScatterInstanceBuffer,
		offset: Vector3,
		rotation_degrees: Vector3,
		scale: Vector3,
		maximum: int,
) -> void:
	if buffer.transforms.size() >= maximum:
		return
	var basis := Basis.from_euler(rotation_degrees * PI / 180.0).scaled(scale)
	buffer.transforms.append(Transform3D(basis, offset))
	buffer.normalize()


static func _poisson_cell_valid(
		candidate: Vector3,
		cell: Vector3i,
		grid: Dictionary,
		radius: float,
		flat: bool,
) -> bool:
	var min_y := 0 if flat else -2
	var max_y := 1 if flat else 3
	for x in range(-2, 3):
		for y in range(min_y, max_y):
			for z in range(-2, 3):
				for existing in Array(grid.get(cell + Vector3i(x, y, z), [])):
					if candidate.distance_squared_to(existing) < radius * radius:
						return false
	return true


static func _append_edge_transform(
		buffer: ScatterInstanceBuffer,
		edge: ScatterEdge,
		weight: float,
		align: bool,
) -> void:
	var direction := edge.b - edge.a
	var basis := Basis()
	if align and direction.length_squared() > 0.000001:
		basis = ScatterMath.basis_from_forward(direction.normalized(), Vector3.UP)
	buffer.transforms.append(Transform3D(basis, edge.a.lerp(edge.b, weight)))


static func _remove_new_outside(
		buffer: ScatterInstanceBuffer,
		first_new: int,
		region: ScatterRegionValue,
) -> void:
	if region == null:
		return
	for index in range(buffer.transforms.size() - 1, first_new - 1, -1):
		if not region.contains(buffer.transforms[index].origin):
			buffer.remove_at(index)
