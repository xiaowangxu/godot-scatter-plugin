@tool
class_name ScatterGizmoPlugin
extends EditorNode3DGizmoPlugin

var _brush_previews := {}


func _init() -> void:
	create_material("region", Color(0.28, 0.82, 0.72, 0.95))
	create_material("paint", Color(0.22, 0.72, 1.0, 0.9))
	create_material("disconnected", Color(0.48, 0.52, 0.58, 0.38))
	create_material("cursor", Color(0.35, 1.0, 0.45, 1.0))
	create_material("erase", Color(1.0, 0.28, 0.32, 1.0))


func _get_gizmo_name() -> String:
	return "Scatter Regions"


func _get_priority() -> int:
	return 1


func _has_gizmo(node_3d: Node3D) -> bool:
	return node_3d is MultiMeshInstance3D and node_3d.has_meta(ScatterGenerator.META_KEY)


func set_brush_preview(target: MultiMeshInstance3D, position: Vector3, normal: Vector3, radius: float, erase: bool) -> void:
	if not is_instance_valid(target): return
	if _brush_previews == null: _brush_previews = {}
	_brush_previews[target.get_instance_id()] = {
		"position": position,
		"normal": normal,
		"radius": radius,
		"erase": erase,
	}
	target.update_gizmos()


func clear_brush_preview(target: MultiMeshInstance3D) -> void:
	if not is_instance_valid(target): return
	if _brush_previews == null: _brush_previews = {}
	_brush_previews.erase(target.get_instance_id())
	target.update_gizmos()


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var target := gizmo.get_node_3d() as MultiMeshInstance3D
	if not is_instance_valid(target): return
	var config = target.get_meta(ScatterGenerator.META_KEY)
	if not config is ScatterConfig: return
	config.ensure_graph()
	var connected_ids := _connected_region_ids(config)
	for entry in config.nodes:
		if not entry.get("enabled", true) or not ScatterSchema.is_region_source(entry.get("type", "")): continue
		var is_connected := connected_ids.has(int(entry.get("id", 0)))
		var material_name := "region" if is_connected else "disconnected"
		var lines := _region_lines(entry)
		if lines.is_empty(): continue
		if entry.get("type", "") == "paint_region" and is_connected: material_name = "paint"
		gizmo.add_lines(lines, get_material(material_name, gizmo), false)
	if _brush_previews == null: _brush_previews = {}
	var preview: Dictionary = _brush_previews.get(target.get_instance_id(), {})
	if not preview.is_empty():
		var cursor_lines := _circle_lines(preview.position, preview.normal, preview.radius, true)
		gizmo.add_lines(cursor_lines, get_material("erase" if preview.erase else "cursor", gizmo), false)


func _connected_region_ids(config: ScatterConfig) -> Dictionary:
	var result := {}
	var final_output := config.final_output_node()
	if final_output.is_empty(): return result
	var pending: Array[int] = []
	for connection in config.connections:
		if int(connection.get("to_id", 0)) != int(final_output.id): continue
		var group := config.find_node(int(connection.get("from_id", 0)))
		if group.is_empty() or not group.get("enabled", true) or not ScatterSchema.is_group(group.get("type", "")): continue
		var region_connection := config.incoming_connection(int(group.id), 0)
		if not region_connection.is_empty(): pending.append(int(region_connection.from_id))
	while not pending.is_empty():
		var id := pending.pop_back()
		if result.has(id): continue
		result[id] = true
		var entry := config.find_node(id)
		if not ScatterSchema.is_region_operator(entry.get("type", "")): continue
		for port in 2:
			var source := config.incoming_connection(id, port)
			if not source.is_empty(): pending.append(int(source.from_id))
	return result


static func _region_lines(entry: Dictionary) -> PackedVector3Array:
	var lines := PackedVector3Array()
	var p: Dictionary = entry.get("params", {})
	match String(entry.get("type", "")):
		"shape_box":
			var corners := ScatterGenerator._box_corners(p.get("center", Vector3.ZERO), p.get("size", Vector3.ONE), p.get("rotation", Vector3.ZERO))
			for pair in [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]:
				lines.append(corners[pair[0]])
				lines.append(corners[pair[1]])
		"shape_sphere":
			var center: Vector3 = p.get("center", Vector3.ZERO)
			var radius := float(p.get("radius", 1.0))
			for axis in 3:
				for i in 48:
					var a0 := TAU * i / 48.0
					var a1 := TAU * (i + 1) / 48.0
					var va := Vector3(cos(a0) * radius, 0, sin(a0) * radius)
					var vb := Vector3(cos(a1) * radius, 0, sin(a1) * radius)
					if axis == 1:
						va = Vector3(va.x, va.z, 0)
						vb = Vector3(vb.x, vb.z, 0)
					elif axis == 2:
						va = Vector3(0, va.x, va.z)
						vb = Vector3(0, vb.x, vb.z)
					lines.append(center + va)
					lines.append(center + vb)
		"shape_path":
			var points: PackedVector3Array = p.get("points", PackedVector3Array())
			for i in maxi(0, points.size() - 1):
				lines.append(points[i])
				lines.append(points[i + 1])
			if p.get("closed", false) and points.size() > 2:
				lines.append(points[-1])
				lines.append(points[0])
		"paint_region":
			var strokes: Array = p.get("strokes", [])
			var step := maxi(1, ceili(float(strokes.size()) / 2500.0))
			var offset := float(p.get("surface_offset", 0.0))
			for i in range(0, strokes.size(), step):
				var stroke: Dictionary = strokes[i]
				var normal := Vector3(stroke.get("normal", Vector3.UP)).normalized()
				var center := Vector3(stroke.get("position", Vector3.ZERO)) + normal * offset
				lines.append_array(_circle_lines(center, normal, float(stroke.get("radius", 1.0)), false))
	return lines


static func _circle_lines(center: Vector3, normal: Vector3, radius: float, with_cross: bool) -> PackedVector3Array:
	var lines := PackedVector3Array()
	normal = normal.normalized()
	var tangent := normal.cross(Vector3.FORWARD).normalized()
	if tangent.length_squared() < 0.001: tangent = normal.cross(Vector3.RIGHT).normalized()
	var bitangent := normal.cross(tangent).normalized()
	for i in 48:
		var a0 := TAU * float(i) / 48.0
		var a1 := TAU * float(i + 1) / 48.0
		lines.append(center + (tangent * cos(a0) + bitangent * sin(a0)) * radius)
		lines.append(center + (tangent * cos(a1) + bitangent * sin(a1)) * radius)
	if with_cross:
		lines.append(center - tangent * radius)
		lines.append(center + tangent * radius)
		lines.append(center - bitangent * radius)
		lines.append(center + bitangent * radius)
		lines.append(center)
		lines.append(center + normal * minf(radius * 0.5, 1.0))
	return lines
