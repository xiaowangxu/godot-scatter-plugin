@tool
class_name ScatterGenerator
extends RefCounted

const META_KEY := &"_scatter_config"
const MAX_GENERATED := 1_000_000


static func ensure_config(target: MultiMeshInstance3D) -> ScatterConfig:
	var existing = target.get_meta(META_KEY) if target.has_meta(META_KEY) else null
	if existing is ScatterConfig:
		if not existing.nodes.is_empty(): existing.ensure_graph()
		return existing
	var config := ScatterConfig.new()
	config.resource_local_to_scene = true
	# Adopt existing instance data so adding Scatter to a populated native
	# MultiMesh is non-destructive.
	if target.multimesh != null:
		for i in target.multimesh.instance_count:
			config.manual_transforms.append(target.multimesh.get_instance_transform(i))
			config.manual_colors.append(target.multimesh.get_instance_color(i) if target.multimesh.use_colors else Color.WHITE)
			config.manual_custom_data.append(target.multimesh.get_instance_custom_data(i) if target.multimesh.use_custom_data else Color(0, 0, 0, 0))
	target.set_meta(META_KEY, config)
	return config


static func build(target: MultiMeshInstance3D, config: ScatterConfig, visited := {}) -> Dictionary:
	if not is_instance_valid(target):
		return {"ok": false, "error": "Target is no longer valid."}
	var target_id := target.get_instance_id()
	if visited.has(target_id):
		return {"ok": false, "error": "Proxy cycle detected."}
	visited[target_id] = true
	config.ensure_graph()
	var output := config.output_node()
	if output.is_empty():
		visited.erase(target_id)
		return {"ok": false, "error": "Scatter graph has no Output node."}

	var region_connection := config.incoming_connection(int(output.id), 0)
	var region := {"type": "empty"}
	if not region_connection.is_empty():
		region = _compile_region(config, int(region_connection.from_id), {})
		if region.has("error"):
			visited.erase(target_id)
			return {"ok": false, "error": region.error}

	var placement_connection := config.incoming_connection(int(output.id), 1)
	var data := _manual_result(config)
	if not placement_connection.is_empty():
		data = _evaluate_placement(config, int(placement_connection.from_id), region, target, visited, {}, true)
		if not data.get("ok", false):
			visited.erase(target_id)
			return data
	var transforms: Array[Transform3D] = data.transforms
	var colors: Array[Color] = data.colors
	var custom_data: Array[Color] = data.custom_data
	if transforms.size() > MAX_GENERATED:
		transforms.resize(MAX_GENERATED)
	_resize_colors(colors, transforms.size(), Color.WHITE)
	_resize_colors(custom_data, transforms.size(), Color(0, 0, 0, 0))

	visited.erase(target_id)
	return {
		"ok": true,
		"transforms": transforms,
		"colors": colors,
		"custom_data": custom_data,
	}


static func _manual_result(config: ScatterConfig) -> Dictionary:
	var transforms: Array[Transform3D] = config.manual_transforms.duplicate()
	var colors: Array[Color] = config.manual_colors.duplicate()
	var custom_data: Array[Color] = config.manual_custom_data.duplicate()
	_resize_colors(colors, transforms.size(), Color.WHITE)
	_resize_colors(custom_data, transforms.size(), Color(0, 0, 0, 0))
	return {"ok": true, "transforms": transforms, "colors": colors, "custom_data": custom_data}


static func _empty_result() -> Dictionary:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var custom_data: Array[Color] = []
	return {"ok": true, "transforms": transforms, "colors": colors, "custom_data": custom_data}


static func _evaluate_placement(config: ScatterConfig, node_id: int, region: Dictionary, target: MultiMeshInstance3D, visited: Dictionary, active: Dictionary, allow_manual: bool) -> Dictionary:
	if active.has(node_id):
		return {"ok": false, "error": "Placement graph contains a cycle at node %d." % node_id}
	var entry := config.find_node(node_id)
	if entry.is_empty():
		return _manual_result(config) if allow_manual else _empty_result()
	if not entry.get("enabled", true):
		var bypass := config.incoming_connection(node_id, 0)
		return _evaluate_placement(config, int(bypass.from_id), region, target, visited, active, allow_manual) if not bypass.is_empty() else (_manual_result(config) if allow_manual else _empty_result())
	var type := String(entry.get("type", ""))
	if not ScatterSchema.is_placement(type):
		return {"ok": false, "error": "Node %d is not a Placement node." % node_id}
	active[node_id] = true

	var data: Dictionary
	if type == "placement_merge":
		var a_connection := config.incoming_connection(node_id, 0)
		var b_connection := config.incoming_connection(node_id, 1)
		var a := _evaluate_placement(config, int(a_connection.get("from_id", 0)), region, target, visited, active.duplicate(), allow_manual) if not a_connection.is_empty() else (_manual_result(config) if allow_manual else _empty_result())
		var b := _evaluate_placement(config, int(b_connection.get("from_id", 0)), region, target, visited, active.duplicate(), false) if not b_connection.is_empty() else _empty_result()
		if not a.get("ok", false): return a
		if not b.get("ok", false): return b
		data = a
		data.transforms.append_array(b.transforms)
		data.colors.append_array(b.colors)
		data.custom_data.append_array(b.custom_data)
	else:
		var incoming := config.incoming_connection(node_id, 0)
		data = _evaluate_placement(config, int(incoming.from_id), region, target, visited, active, allow_manual) if not incoming.is_empty() else (_manual_result(config) if allow_manual else _empty_result())
		if not data.get("ok", false): return data
		_apply_placement_node(entry, data, region, target, visited, config.seed)
	active.erase(node_id)
	return data


static func _apply_placement_node(entry: Dictionary, data: Dictionary, region: Dictionary, target: MultiMeshInstance3D, visited: Dictionary, global_seed: int) -> void:
	var transforms: Array[Transform3D] = data.transforms
	var colors: Array[Color] = data.colors
	var custom_data: Array[Color] = data.custom_data
	var type := String(entry.get("type", ""))
	var params: Dictionary = entry.get("params", {})
	var node_seed := int(entry.get("custom_seed", 0)) if entry.get("override_seed", false) else global_seed ^ (int(entry.get("id", 0)) * 0x45d9f3b)
	var rng := RandomNumberGenerator.new()
	rng.seed = node_seed
	var bounds := _domain_bounds(region)
	match type:
		"create_random": _append_random(transforms, region, bounds, params, rng)
		"create_grid": _append_grid(transforms, region, bounds, params)
		"create_poisson": _append_poisson(transforms, region, bounds, params, rng)
		"edge_random": _append_edges_random(transforms, region, params, rng)
		"edge_even": _append_edges_even(transforms, region, params)
		"edge_continuous": _append_edges_continuous(transforms, region, params)
		"single": _append_single(transforms, params)
		"array": _apply_array(transforms, colors, custom_data, params, rng)
		"transform": _apply_transform(transforms, params, target)
		"position": _apply_position(transforms, params, target)
		"rotation": _apply_rotation(transforms, params, target)
		"scale": _apply_scale(transforms, params)
		"random_transform": _apply_random_transform(transforms, params, rng, target)
		"random_rotation": _apply_random_rotation(transforms, params, rng, target)
		"look_at": _apply_look_at(transforms, params)
		"snap": _apply_snap(transforms, params)
		"relax": _apply_relax(transforms, params)
		"clusterize": _apply_clusterize(transforms, colors, custom_data, params, bounds)
		"project": _apply_projection(transforms, colors, custom_data, params, target)
		"remove_outside": _apply_remove_outside(transforms, colors, custom_data, region, params)
		"remove_random": _apply_remove_random(transforms, colors, custom_data, params, rng)
		"proxy": _apply_proxy(transforms, colors, custom_data, params, target, visited)
		"random_color":
			_resize_colors(colors, transforms.size(), Color.WHITE)
			_randomize_colors(colors, params, rng)
		"random_custom_data":
			_resize_colors(custom_data, transforms.size(), Color(0, 0, 0, 0))
			_randomize_colors(custom_data, params, rng)
	if transforms.size() > MAX_GENERATED:
		transforms.resize(MAX_GENERATED)
	_resize_colors(colors, transforms.size(), Color.WHITE)
	_resize_colors(custom_data, transforms.size(), Color(0, 0, 0, 0))


static func apply_to_multimesh(target: MultiMeshInstance3D, result: Dictionary) -> void:
	if not result.get("ok", false):
		return
	var mm := target.multimesh
	if mm == null:
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		target.multimesh = mm
	elif not mm.resource_local_to_scene and mm.get_reference_count() > 1:
		mm = mm.duplicate(true)
		target.multimesh = mm
	mm.resource_local_to_scene = true
	var transforms: Array = result.transforms
	var colors: Array = result.colors
	var custom_data: Array = result.custom_data
	mm.instance_count = 0
	mm.use_colors = true
	mm.use_custom_data = true
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i] if i < colors.size() else Color.WHITE)
		mm.set_instance_custom_data(i, custom_data[i] if i < custom_data.size() else Color(0, 0, 0, 0))
	mm.visible_instance_count = -1
	target.notify_property_list_changed()


static func _compile_region(config: ScatterConfig, node_id: int, active: Dictionary) -> Dictionary:
	if active.has(node_id):
		return {"error": "Region graph contains a cycle at node %d." % node_id}
	var entry := config.find_node(node_id)
	if entry.is_empty() or not entry.get("enabled", true):
		return {"type": "empty"}
	var type := String(entry.get("type", ""))
	if ScatterSchema.is_region_source(type):
		return {"type": type, "params": entry.get("params", {}), "id": node_id}
	if not ScatterSchema.is_region_operator(type):
		return {"error": "Node %d is not a Region node." % node_id}
	active[node_id] = true
	var a_connection := config.incoming_connection(node_id, 0)
	var b_connection := config.incoming_connection(node_id, 1)
	var a := _compile_region(config, int(a_connection.get("from_id", 0)), active.duplicate()) if not a_connection.is_empty() else {"type": "empty"}
	var b := _compile_region(config, int(b_connection.get("from_id", 0)), active.duplicate()) if not b_connection.is_empty() else {"type": "empty"}
	if a.has("error"): return a
	if b.has("error"): return b
	return {"type": type, "a": a, "b": b, "id": node_id}


static func _domain_bounds(region: Dictionary) -> AABB:
	var type := String(region.get("type", "empty"))
	var p: Dictionary = region.get("params", {})
	match type:
		"shape_box":
			var size: Vector3 = _positive_vec3(p.get("size", Vector3.ONE))
			var corners := _box_corners(p.get("center", Vector3.ZERO), size, p.get("rotation", Vector3.ZERO))
			var result := AABB(corners[0], Vector3.ZERO)
			for corner in corners: result = result.expand(corner)
			return result
		"shape_sphere":
			var radius := maxf(float(p.get("radius", 1.0)), 0.001)
			return AABB(Vector3(p.get("center", Vector3.ZERO)) - Vector3.ONE * radius, Vector3.ONE * radius * 2.0)
		"shape_path":
			var points: PackedVector3Array = p.get("points", PackedVector3Array())
			if points.is_empty(): return AABB()
			var result := AABB(points[0], Vector3.ZERO)
			for point in points: result = result.expand(point)
			return result.grow(maxf(float(p.get("thickness", 0.0)), 0.001))
		"paint_region":
			var strokes: Array = p.get("strokes", [])
			if strokes.is_empty(): return AABB()
			var first: Dictionary = strokes[0]
			var first_radius := maxf(float(first.get("radius", 1.0)), 0.001)
			var result := AABB(Vector3(first.get("position", Vector3.ZERO)) - Vector3.ONE * first_radius, Vector3.ONE * first_radius * 2.0)
			for stroke in strokes:
				var radius := maxf(float(stroke.get("radius", 1.0)), 0.001)
				var stroke_bounds := AABB(Vector3(stroke.get("position", Vector3.ZERO)) - Vector3.ONE * radius, Vector3.ONE * radius * 2.0)
				result = result.merge(stroke_bounds)
			return result.grow(maxf(float(p.get("depth", 0.35)), 0.01) * 0.5)
		"region_union":
			if _region_is_empty(region.a): return _domain_bounds(region.b)
			if _region_is_empty(region.b): return _domain_bounds(region.a)
			return _domain_bounds(region.a).merge(_domain_bounds(region.b))
		"region_intersection":
			return _aabb_intersection(_domain_bounds(region.a), _domain_bounds(region.b))
		"region_subtract":
			return _domain_bounds(region.a)
	return AABB()


static func _region_is_empty(region: Dictionary) -> bool:
	var type := String(region.get("type", "empty"))
	if type == "empty": return true
	if type == "paint_region": return Array(region.get("params", {}).get("strokes", [])).is_empty()
	if type == "region_union": return _region_is_empty(region.a) and _region_is_empty(region.b)
	if type in ["region_intersection", "region_subtract"]: return _region_is_empty(region.a)
	return false


static func _aabb_intersection(a: AABB, b: AABB) -> AABB:
	var start := Vector3(maxf(a.position.x, b.position.x), maxf(a.position.y, b.position.y), maxf(a.position.z, b.position.z))
	var finish := Vector3(minf(a.end.x, b.end.x), minf(a.end.y, b.end.y), minf(a.end.z, b.end.z))
	if finish.x < start.x or finish.y < start.y or finish.z < start.z:
		return AABB()
	return AABB(start, finish - start)


static func _point_in_domain(point: Vector3, region: Dictionary) -> bool:
	var type := String(region.get("type", "empty"))
	if type == "region_union": return _point_in_domain(point, region.a) or _point_in_domain(point, region.b)
	if type == "region_intersection": return _point_in_domain(point, region.a) and _point_in_domain(point, region.b)
	if type == "region_subtract": return _point_in_domain(point, region.a) and not _point_in_domain(point, region.b)
	if ScatterSchema.is_region_source(type): return _point_in_shape(point, region)
	return false


static func _point_in_exclusions(point: Vector3, region: Dictionary) -> bool:
	var type := String(region.get("type", "empty"))
	if type == "region_subtract": return _point_in_domain(point, region.b) or _point_in_exclusions(point, region.a)
	if type in ["region_union", "region_intersection"]: return _point_in_exclusions(point, region.a) or _point_in_exclusions(point, region.b)
	return false


static func _point_in_shape(point: Vector3, shape: Dictionary) -> bool:
	var p: Dictionary = shape.get("params", {})
	match String(shape.get("type", "")):
		"shape_box":
			var size: Vector3 = _positive_vec3(p.get("size", Vector3.ONE))
			var rotation := Basis.from_euler(Vector3(p.get("rotation", Vector3.ZERO)) * PI / 180.0)
			var local := rotation.inverse() * (point - Vector3(p.get("center", Vector3.ZERO)))
			return absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5 and absf(local.z) <= size.z * 0.5
		"shape_sphere":
			return point.distance_squared_to(p.get("center", Vector3.ZERO)) <= pow(float(p.get("radius", 1.0)), 2.0)
		"shape_path":
			var points: PackedVector3Array = p.get("points", PackedVector3Array())
			var thickness: float = float(p.get("thickness", 0.0))
			for edge in _path_edges(points, p.get("closed", false)):
				if _distance_to_segment(point, edge.a, edge.b) <= thickness:
					return true
		"paint_region":
			var depth := maxf(float(p.get("depth", 0.35)), 0.01)
			var offset := float(p.get("surface_offset", 0.0))
			for stroke in Array(p.get("strokes", [])):
				var normal := Vector3(stroke.get("normal", Vector3.UP)).normalized()
				var center := Vector3(stroke.get("position", Vector3.ZERO)) + normal * offset
				var delta := point - center
				if absf(delta.dot(normal)) <= depth * 0.5:
					var tangent_delta := delta - normal * delta.dot(normal)
					if tangent_delta.length_squared() <= pow(float(stroke.get("radius", 1.0)), 2.0):
						return true
	return false


static func _sample_region_point(region: Dictionary, bounds: AABB, rng: RandomNumberGenerator, flat: bool) -> Vector3:
	if _region_is_empty(region): return Vector3.INF
	var type := String(region.get("type", "empty"))
	if type == "paint_region":
		var params: Dictionary = region.get("params", {})
		var strokes: Array = params.get("strokes", [])
		if strokes.is_empty(): return Vector3.INF
		var stroke: Dictionary = strokes[rng.randi_range(0, strokes.size() - 1)]
		var normal := Vector3(stroke.get("normal", Vector3.UP)).normalized()
		var tangent := normal.cross(Vector3.FORWARD).normalized()
		if tangent.length_squared() < 0.001: tangent = normal.cross(Vector3.RIGHT).normalized()
		var bitangent := normal.cross(tangent).normalized()
		var radius := sqrt(rng.randf()) * maxf(float(stroke.get("radius", 1.0)), 0.001)
		var angle := rng.randf() * TAU
		return Vector3(stroke.get("position", Vector3.ZERO)) + normal * float(params.get("surface_offset", 0.0)) + tangent * cos(angle) * radius + bitangent * sin(angle) * radius
	if type == "region_union":
		var choose_a := rng.randf() < 0.5
		var first: Dictionary = region.a if choose_a else region.b
		var second: Dictionary = region.b if choose_a else region.a
		var point := _sample_region_point(first, _domain_bounds(first), rng, flat)
		return point if point.is_finite() else _sample_region_point(second, _domain_bounds(second), rng, flat)
	if type == "region_subtract":
		for attempt in 100:
			var point := _sample_region_point(region.a, _domain_bounds(region.a), rng, flat)
			if point.is_finite() and not _point_in_domain(point, region.b): return point
		return Vector3.INF
	if type == "region_intersection":
		var a_bounds := _domain_bounds(region.a)
		var b_bounds := _domain_bounds(region.b)
		var source: Dictionary = region.a if a_bounds.get_volume() <= b_bounds.get_volume() else region.b
		for attempt in 100:
			var point := _sample_region_point(source, _domain_bounds(source), rng, flat)
			if point.is_finite() and _point_in_domain(point, region): return point
		return Vector3.INF
	for attempt in 100:
		var point := Vector3(
			rng.randf_range(bounds.position.x, bounds.end.x),
			bounds.get_center().y if flat else rng.randf_range(bounds.position.y, bounds.end.y),
			rng.randf_range(bounds.position.z, bounds.end.z)
		)
		if _point_in_domain(point, region): return point
	return Vector3.INF


static func _append_random(out: Array[Transform3D], region: Dictionary, bounds: AABB, p: Dictionary, rng: RandomNumberGenerator) -> void:
	var amount := mini(int(p.get("amount", 10)), MAX_GENERATED - out.size())
	var flat: bool = p.get("restrict_height", true)
	for i in amount:
		var point := _sample_region_point(region, bounds, rng, flat)
		if not point.is_finite(): break
		out.append(Transform3D(Basis(), point))


static func _append_grid(out: Array[Transform3D], region: Dictionary, bounds: AABB, p: Dictionary) -> void:
	if _region_is_empty(region): return
	var spacing: Vector3 = _positive_vec3(p.get("spacing", Vector3.ONE))
	var flat: bool = p.get("restrict_height", true)
	var y_values: Array[float] = [bounds.get_center().y]
	if not flat:
		y_values.clear()
		var y := bounds.position.y
		while y <= bounds.end.y + 0.0001:
			y_values.append(y)
			y += spacing.y
	var x := bounds.position.x
	while x <= bounds.end.x + 0.0001 and out.size() < MAX_GENERATED:
		for y in y_values:
			var z := bounds.position.z
			while z <= bounds.end.z + 0.0001 and out.size() < MAX_GENERATED:
				var point := Vector3(x, y, z)
				if _point_in_domain(point, region):
					out.append(Transform3D(Basis(), point))
				z += spacing.z
		x += spacing.x


static func _append_poisson(out: Array[Transform3D], region: Dictionary, bounds: AABB, p: Dictionary, rng: RandomNumberGenerator) -> void:
	if _region_is_empty(region): return
	var radius := maxf(float(p.get("radius", 1.0)), 0.001)
	var max_points := mini(int(p.get("max_points", 10000)), MAX_GENERATED - out.size())
	var rejection := maxi(int(p.get("samples_before_rejection", 15)), 1)
	var flat: bool = p.get("restrict_height", true)
	var points: Array[Vector3] = []
	var grid := {}
	var cell_size := radius / sqrt(2.0 if flat else 3.0)
	var failed := 0
	while points.size() < max_points and failed < rejection * max(20, points.size()):
		var candidate := _sample_region_point(region, bounds, rng, flat)
		if not candidate.is_finite() or not _point_in_domain(candidate, region):
			failed += 1
			continue
		var relative := (candidate - bounds.position) / cell_size
		var cell := Vector3i(floori(relative.x), 0 if flat else floori(relative.y), floori(relative.z))
		var valid := _poisson_cell_is_valid(candidate, cell, grid, radius, flat)
		if valid:
			points.append(candidate)
			var bucket: Array = grid.get(cell, [])
			bucket.append(candidate)
			grid[cell] = bucket
			failed = 0
		else:
			failed += 1
	for point in points:
		out.append(Transform3D(Basis(), point))


static func _poisson_cell_is_valid(candidate: Vector3, cell: Vector3i, grid: Dictionary, radius: float, flat: bool) -> bool:
	var min_y := 0 if flat else -2
	var max_y := 1 if flat else 3
	for x in range(-2, 3):
		for y in range(min_y, max_y):
			for z in range(-2, 3):
				var bucket: Array = grid.get(cell + Vector3i(x, y, z), [])
				for existing in bucket:
					if candidate.distance_squared_to(existing) < radius * radius: return false
	return true


static func _region_sources(region: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var type := String(region.get("type", "empty"))
	if ScatterSchema.is_region_source(type):
		result.append(region)
	elif type in ["region_union", "region_intersection"]:
		result.append_array(_region_sources(region.a))
		result.append_array(_region_sources(region.b))
	elif type == "region_subtract":
		result.append_array(_region_sources(region.a))
	return result


static func _shape_edges(region: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for shape in _region_sources(region):
		var p: Dictionary = shape.get("params", {})
		match String(shape.get("type", "")):
			"shape_path":
				result.append_array(_path_edges(p.get("points", PackedVector3Array()), p.get("closed", false)))
			"shape_box":
				var c: Vector3 = p.get("center", Vector3.ZERO)
				var h: Vector3 = _positive_vec3(p.get("size", Vector3.ONE)) * 0.5
				var corners := _box_corners(c, h * 2.0, p.get("rotation", Vector3.ZERO))
				for pair in [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]:
					result.append({"a": corners[pair[0]], "b": corners[pair[1]]})
			"shape_sphere":
				var c: Vector3 = p.get("center", Vector3.ZERO)
				var r: float = p.get("radius", 1.0)
				for axis in 3:
					for i in 32:
						var a0 := TAU * float(i) / 32.0
						var a1 := TAU * float(i + 1) / 32.0
						var va := Vector3(cos(a0) * r, 0, sin(a0) * r)
						var vb := Vector3(cos(a1) * r, 0, sin(a1) * r)
						if axis == 1:
							va = Vector3(va.x, va.z, 0); vb = Vector3(vb.x, vb.z, 0)
						elif axis == 2:
							va = Vector3(0, va.x, va.z); vb = Vector3(0, vb.x, vb.z)
						result.append({"a": c + va, "b": c + vb})
	return result


static func _append_edges_random(out: Array[Transform3D], region: Dictionary, p: Dictionary, rng: RandomNumberGenerator) -> void:
	var edges := _shape_edges(region)
	if edges.is_empty(): return
	var first_new := out.size()
	var count := mini(int(p.get("instance_count", 10)), MAX_GENERATED - out.size())
	for i in count:
		var edge: Dictionary = edges[rng.randi_range(0, edges.size() - 1)]
		_append_edge_transform(out, edge, rng.randf(), p.get("align_to_path", false))
	_remove_new_outside(out, first_new, region)


static func _append_edges_even(out: Array[Transform3D], region: Dictionary, p: Dictionary) -> void:
	var spacing := maxf(float(p.get("spacing", 1.0)), 0.001)
	var offset := float(p.get("offset", 0.0))
	var first_new := out.size()
	for edge in _shape_edges(region):
		var length: float = edge.a.distance_to(edge.b)
		var distance := offset
		while distance <= length and out.size() < MAX_GENERATED:
			_append_edge_transform(out, edge, clampf(distance / maxf(length, 0.0001), 0.0, 1.0), p.get("align_to_path", false))
			distance += spacing
	_remove_new_outside(out, first_new, region)


static func _append_edges_continuous(out: Array[Transform3D], region: Dictionary, p: Dictionary) -> void:
	var length_item := maxf(float(p.get("item_length", 2.0)), 0.001)
	var first_new := out.size()
	for edge in _shape_edges(region):
		var length: float = edge.a.distance_to(edge.b)
		var count := maxi(1, ceili(length / length_item))
		for i in count:
			_append_edge_transform(out, edge, (float(i) + 0.5) / count, true)
	_remove_new_outside(out, first_new, region)


static func _remove_new_outside(out: Array[Transform3D], first_new: int, region: Dictionary) -> void:
	for i in range(out.size() - 1, first_new - 1, -1):
		if not _point_in_domain(out[i].origin, region):
			out.remove_at(i)


static func _append_edge_transform(out: Array[Transform3D], edge: Dictionary, weight: float, align: bool) -> void:
	var direction: Vector3 = Vector3(edge.b) - Vector3(edge.a)
	var basis := Basis()
	if align and direction.length_squared() > 0.000001:
		basis = _basis_from_forward(direction.normalized(), Vector3.UP)
	out.append(Transform3D(basis, Vector3(edge.a).lerp(edge.b, weight)))


static func _append_single(out: Array[Transform3D], p: Dictionary) -> void:
	var basis := Basis.from_euler(Vector3(p.get("rotation", Vector3.ZERO)) * PI / 180.0)
	basis = basis.scaled(p.get("scale", Vector3.ONE))
	out.append(Transform3D(basis, p.get("offset", Vector3.ZERO)))


static func _apply_array(transforms: Array[Transform3D], colors: Array[Color], custom_data: Array[Color], p: Dictionary, rng: RandomNumberGenerator) -> void:
	_resize_colors(colors, transforms.size(), Color.WHITE)
	_resize_colors(custom_data, transforms.size(), Color(0, 0, 0, 0))
	var originals := transforms.duplicate()
	var original_colors := colors.duplicate()
	var original_custom := custom_data.duplicate()
	var amount := maxi(1, int(p.get("amount", 1)))
	var min_amount := int(p.get("min_amount", -1))
	var offset: Vector3 = p.get("offset", Vector3.ZERO)
	var rot: Vector3 = p.get("rotation", Vector3.ZERO)
	var scale: Vector3 = p.get("scale", Vector3.ONE)
	var pivot: Vector3 = p.get("rotation_pivot", Vector3.ZERO)
	for original_index in originals.size():
		var original: Transform3D = originals[original_index]
		var copy_count := rng.randi_range(maxi(0, min_amount), amount) if min_amount >= 0 else amount
		for n in range(1, copy_count + 1):
			if transforms.size() >= MAX_GENERATED: return
			var copy: Transform3D = original
			var delta_basis := Basis.from_euler(rot * PI / 180.0 * n)
			copy.basis = copy.basis * delta_basis if p.get("local_rotation", false) else delta_basis * copy.basis
			var scaled := _pow_vec3(scale, n)
			copy.basis = copy.basis.scaled(scaled) if p.get("local_scale", true) else copy.basis.orthonormalized().scaled(copy.basis.get_scale() * scaled)
			var move := offset * n
			if p.get("local_offset", false): move = original.basis.orthonormalized() * move
			copy.origin += move
			var active_pivot: Vector3 = original.origin if p.get("individual_rotation_pivots", true) else pivot
			copy.origin = active_pivot + delta_basis * (copy.origin - active_pivot)
			transforms.append(copy)
			colors.append(original_colors[original_index])
			custom_data.append(original_custom[original_index])
	if p.get("randomize_indices", true):
		for i in range(transforms.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap: Transform3D = transforms[i]
			transforms[i] = transforms[j]
			transforms[j] = swap
			var swap_color: Color = colors[i]; colors[i] = colors[j]; colors[j] = swap_color
			var swap_custom: Color = custom_data[i]; custom_data[i] = custom_data[j]; custom_data[j] = swap_custom


static func _apply_transform(transforms: Array[Transform3D], p: Dictionary, target: Node3D) -> void:
	var delta := Transform3D(Basis.from_euler(Vector3(p.get("rotation", Vector3.ZERO)) * PI / 180.0).scaled(p.get("scale", Vector3.ONE)), p.get("position", Vector3.ZERO))
	var space := int(p.get("space", 2))
	for i in transforms.size():
		if space == 2: transforms[i] = transforms[i] * delta
		elif space == 0: transforms[i] = target.global_transform.affine_inverse() * delta * target.global_transform * transforms[i]
		else: transforms[i] = delta * transforms[i]


static func _apply_position(transforms: Array[Transform3D], p: Dictionary, target: Node3D) -> void:
	var value: Vector3 = p.get("position", Vector3.ZERO)
	var operation := int(p.get("operation", 0))
	var space := int(p.get("space", 1))
	if space == 0: value = target.global_transform.basis.inverse() * value
	for i in transforms.size():
		var t := transforms[i]
		var v := t.basis * value if space == 2 else value
		if operation == 0: t.origin += v
		elif operation == 1: t.origin *= v
		else: t.origin = v
		transforms[i] = t


static func _apply_rotation(transforms: Array[Transform3D], p: Dictionary, target: Node3D) -> void:
	var value: Vector3 = p.get("rotation", Vector3.ZERO)
	var operation := int(p.get("operation", 0))
	var delta := Basis.from_euler(value * PI / 180.0)
	for i in transforms.size():
		var t := transforms[i]
		if operation == 2:
			t.basis = delta.scaled(t.basis.get_scale())
		elif operation == 1:
			var euler := t.basis.get_euler() * value
			t.basis = Basis.from_euler(euler).scaled(t.basis.get_scale())
		elif int(p.get("space", 2)) == 2:
			t.basis *= delta
		else:
			t.basis = delta * t.basis
		transforms[i] = t


static func _apply_scale(transforms: Array[Transform3D], p: Dictionary) -> void:
	var value: Vector3 = p.get("scale", Vector3.ONE)
	var operation := int(p.get("operation", 1))
	for i in transforms.size():
		var t := transforms[i]
		var current := t.basis.get_scale()
		var next := current + value if operation == 0 else current * value if operation == 1 else value
		t.basis = t.basis.orthonormalized().scaled(next)
		transforms[i] = t


static func _apply_random_transform(transforms: Array[Transform3D], p: Dictionary, rng: RandomNumberGenerator, target: Node3D) -> void:
	var pos: Vector3 = p.get("position", Vector3.ZERO)
	var rot: Vector3 = p.get("rotation", Vector3.ZERO)
	var scl: Vector3 = p.get("scale", Vector3.ZERO)
	var space := int(p.get("space", 2))
	for i in transforms.size():
		var t := transforms[i]
		var offset := Vector3(rng.randf_range(-pos.x, pos.x), rng.randf_range(-pos.y, pos.y), rng.randf_range(-pos.z, pos.z))
		if space == 2: offset = t.basis.orthonormalized() * offset
		elif space == 0: offset = target.global_transform.basis.inverse() * offset
		t.origin += offset
		var angles := Vector3(rng.randf_range(-rot.x, rot.x), rng.randf_range(-rot.y, rot.y), rng.randf_range(-rot.z, rot.z)) * PI / 180.0
		var delta := Basis.from_euler(angles)
		t.basis = t.basis * delta if space == 2 else delta * t.basis
		var scale_delta := Vector3(1.0 + rng.randf_range(-scl.x, scl.x), 1.0 + rng.randf_range(-scl.y, scl.y), 1.0 + rng.randf_range(-scl.z, scl.z))
		t.basis = t.basis.scaled(scale_delta)
		transforms[i] = t


static func _apply_random_rotation(transforms: Array[Transform3D], p: Dictionary, rng: RandomNumberGenerator, _target: Node3D) -> void:
	var rotation: Vector3 = p.get("rotation", Vector3(0, 360, 0))
	var snap: Vector3 = p.get("snap_angle", Vector3.ZERO)
	var space := int(p.get("space", 2))
	for i in transforms.size():
		var angles := Vector3(_random_snapped(rng, rotation.x, snap.x), _random_snapped(rng, rotation.y, snap.y), _random_snapped(rng, rotation.z, snap.z)) * PI / 180.0
		var t := transforms[i]
		var delta := Basis.from_euler(angles)
		t.basis = t.basis * delta if space == 2 else delta * t.basis
		transforms[i] = t


static func _apply_look_at(transforms: Array[Transform3D], p: Dictionary) -> void:
	var target: Vector3 = p.get("target", Vector3.ZERO)
	var up: Vector3 = p.get("up", Vector3.UP)
	for i in transforms.size():
		var t := transforms[i]
		var direction := target - t.origin
		if direction.length_squared() > 0.000001:
			t.basis = _basis_from_forward(direction.normalized(), up).scaled(t.basis.get_scale())
		transforms[i] = t


static func _apply_snap(transforms: Array[Transform3D], p: Dictionary) -> void:
	var ps: Vector3 = p.get("position_step", Vector3.ZERO)
	var rs: Vector3 = p.get("rotation_step", Vector3.ZERO) * PI / 180.0
	var ss: Vector3 = p.get("scale_step", Vector3.ZERO)
	for i in transforms.size():
		var t := transforms[i]
		t.origin = _snapped_vec3(t.origin, ps)
		var euler := _snapped_vec3(t.basis.get_euler(), rs)
		var scale := _snapped_vec3(t.basis.get_scale(), ss)
		t.basis = Basis.from_euler(euler).scaled(scale)
		transforms[i] = t


static func _apply_relax(transforms: Array[Transform3D], p: Dictionary) -> void:
	if transforms.size() < 2: return
	var offset := float(p.get("offset_step", 0.01))
	var restrict_height: bool = p.get("restrict_height", true)
	for iteration in int(p.get("iterations", 3)):
		var directions: Array[Vector3] = []
		for i in transforms.size():
			var closest := Vector3.ZERO
			var best := INF
			for j in transforms.size():
				if i == j: continue
				var diff: Vector3 = transforms[i].origin - transforms[j].origin
				if diff.length_squared() < best:
					best = diff.length_squared(); closest = diff
			if restrict_height: closest.y = 0.0
			directions.append(closest.normalized() * offset)
		for i in transforms.size(): transforms[i].origin += directions[i]
		offset *= float(p.get("consecutive_step_multiplier", 0.5))


static func _apply_clusterize(transforms: Array[Transform3D], colors: Array[Color], custom_data: Array[Color], p: Dictionary, _bounds: AABB) -> void:
	var path := String(p.get("mask", ""))
	if path.is_empty() or not ResourceLoader.exists(path): return
	var texture = load(path)
	if not texture is Texture2D: return
	var image: Image = texture.get_image()
	if image == null or image.is_empty(): return
	var scale2: Vector2 = p.get("mask_scale", Vector2.ONE)
	var offset: Vector2 = p.get("mask_offset", Vector2.ZERO)
	var angle := deg_to_rad(float(p.get("mask_rotation", 0.0)))
	var ratio := maxf(float(p.get("pixel_to_unit_ratio", 64.0)), 0.001)
	var low := float(p.get("remove_below", 0.1)); var high := float(p.get("remove_above", 1.0))
	for i in range(transforms.size() - 1, -1, -1):
		var origin: Vector3 = transforms[i].origin
		var uv := Vector2(origin.x, origin.z) / ratio + Vector2(0.5, 0.5)
		uv = ((uv - Vector2(0.5, 0.5)).rotated(angle) / scale2) + Vector2(0.5, 0.5) + offset
		var x := clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1)
		var y := clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1)
		var value := image.get_pixel(x, y).get_luminance()
		if value < low or value > high: _remove_instance_at(transforms, colors, custom_data, i)
		elif p.get("scale_transforms", true): transforms[i].basis = transforms[i].basis.scaled(Vector3.ONE * value)


static func _apply_projection(transforms: Array[Transform3D], colors: Array[Color], custom_data: Array[Color], p: Dictionary, target: MultiMeshInstance3D) -> void:
	if not target.is_inside_tree() or target.get_world_3d() == null: return
	var state := target.get_world_3d().direct_space_state
	var dir: Vector3 = p.get("ray_direction", Vector3.DOWN)
	if dir.length_squared() < 0.000001: return
	dir = dir.normalized()
	var length := float(p.get("ray_length", 10.0)); var offset := float(p.get("ray_offset", 1.0))
	for i in range(transforms.size() - 1, -1, -1):
		var local_t := transforms[i]
		var global_origin := target.to_global(local_t.origin)
		var global_dir := (target.global_transform.basis * dir).normalized()
		var query := PhysicsRayQueryParameters3D.create(global_origin - global_dir * offset, global_origin + global_dir * length, int(p.get("collision_mask", 1)))
		var exclude_mask := int(p.get("exclude_mask", 0))
		if exclude_mask != 0:
			var exclude_query := PhysicsRayQueryParameters3D.create(query.from, query.to, exclude_mask)
			if not state.intersect_ray(exclude_query).is_empty():
				_remove_instance_at(transforms, colors, custom_data, i); continue
		var hit := state.intersect_ray(query)
		if hit.is_empty():
			if p.get("remove_points_on_miss", true): _remove_instance_at(transforms, colors, custom_data, i)
			continue
		var normal: Vector3 = hit.normal
		if rad_to_deg(normal.angle_to(Vector3.UP)) > float(p.get("max_slope", 90.0)):
			_remove_instance_at(transforms, colors, custom_data, i); continue
		local_t.origin = target.to_local(hit.position)
		if p.get("align_with_collision_normal", false):
			var local_normal := (target.global_transform.basis.inverse() * normal).normalized()
			local_t.basis = _basis_from_up(local_normal, -local_t.basis.z).scaled(local_t.basis.get_scale())
		transforms[i] = local_t


static func _apply_remove_outside(transforms: Array[Transform3D], colors: Array[Color], custom_data: Array[Color], region: Dictionary, p: Dictionary) -> void:
	for i in range(transforms.size() - 1, -1, -1):
		var remove := _point_in_exclusions(transforms[i].origin, region) if p.get("negative_shapes_only", false) else not _point_in_domain(transforms[i].origin, region)
		if remove: _remove_instance_at(transforms, colors, custom_data, i)


static func _apply_remove_random(transforms: Array[Transform3D], colors: Array[Color], custom_data: Array[Color], p: Dictionary, rng: RandomNumberGenerator) -> void:
	var threshold := float(p.get("probability", 50.0)) / 100.0
	for i in range(transforms.size() - 1, -1, -1):
		if rng.randf() < threshold: _remove_instance_at(transforms, colors, custom_data, i)


static func _apply_proxy(transforms: Array[Transform3D], colors: Array[Color], custom_data: Array[Color], p: Dictionary, target: MultiMeshInstance3D, visited: Dictionary) -> void:
	var path: NodePath = p.get("scatter_node", NodePath())
	var source: Node = target.get_node_or_null(path)
	if not source is MultiMeshInstance3D: return
	var config = source.get_meta(META_KEY) if source.has_meta(META_KEY) else null
	if not config is ScatterConfig: return
	var result := build(source, config, visited)
	if not result.get("ok", false): return
	var source_to_target: Transform3D = target.global_transform.affine_inverse() * (source as MultiMeshInstance3D).global_transform
	for i in result.transforms.size():
		transforms.append(source_to_target * result.transforms[i])
		colors.append(result.colors[i])
		custom_data.append(result.custom_data[i])


static func _randomize_colors(values: Array[Color], p: Dictionary, rng: RandomNumberGenerator) -> void:
	var from: Color = p.get("from", Color.WHITE); var to: Color = p.get("to", Color.WHITE)
	for i in values.size():
		values[i] = Color(rng.randf_range(from.r, to.r), rng.randf_range(from.g, to.g), rng.randf_range(from.b, to.b), rng.randf_range(from.a, to.a))


static func _resize_colors(values: Array[Color], size: int, fill: Color) -> void:
	if values.size() > size: values.resize(size)
	while values.size() < size: values.append(fill)


static func _remove_instance_at(transforms: Array[Transform3D], colors: Array[Color], custom_data: Array[Color], index: int) -> void:
	transforms.remove_at(index)
	if index < colors.size(): colors.remove_at(index)
	if index < custom_data.size(): custom_data.remove_at(index)


static func _path_edges(points: PackedVector3Array, closed: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in maxi(0, points.size() - 1): result.append({"a": points[i], "b": points[i + 1]})
	if closed and points.size() > 2: result.append({"a": points[-1], "b": points[0]})
	return result


static func _distance_to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	if ab.length_squared() < 0.000001: return point.distance_to(a)
	return point.distance_to(a + ab * clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0))


static func _basis_from_up(up: Vector3, forward_hint: Vector3) -> Basis:
	var y := up.normalized()
	var z := forward_hint - y * forward_hint.dot(y)
	if z.length_squared() < 0.000001: z = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
	z = z.normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z).orthonormalized()


static func _basis_from_forward(forward: Vector3, up: Vector3) -> Basis:
	var z := -forward.normalized(); var x := up.cross(z).normalized()
	if x.length_squared() < 0.000001: x = Vector3.RIGHT
	return Basis(x, z.cross(x).normalized(), z).orthonormalized()


static func _random_snapped(rng: RandomNumberGenerator, extent: float, step: float) -> float:
	var value := rng.randf_range(-extent, extent)
	return snappedf(value, step) if step > 0.0 else value


static func _snapped_vec3(value: Vector3, step: Vector3) -> Vector3:
	return Vector3(snappedf(value.x, step.x) if step.x != 0 else value.x, snappedf(value.y, step.y) if step.y != 0 else value.y, snappedf(value.z, step.z) if step.z != 0 else value.z)


static func _positive_vec3(value: Vector3) -> Vector3:
	return Vector3(maxf(absf(value.x), 0.001), maxf(absf(value.y), 0.001), maxf(absf(value.z), 0.001))


static func _box_corners(center: Vector3, size: Vector3, rotation_degrees: Vector3) -> Array[Vector3]:
	var h := _positive_vec3(size) * 0.5
	var basis := Basis.from_euler(rotation_degrees * PI / 180.0)
	var corners: Array[Vector3] = []
	for local in [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]:
		corners.append(center + basis * local)
	return corners


static func _pow_vec3(value: Vector3, exponent: int) -> Vector3:
	return Vector3(pow(value.x, exponent), pow(value.y, exponent), pow(value.z, exponent))
