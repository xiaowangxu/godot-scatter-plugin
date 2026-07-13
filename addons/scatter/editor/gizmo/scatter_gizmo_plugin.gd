@tool
class_name ScatterGizmoPlugin
extends EditorNode3DGizmoPlugin

var _brush_previews: Dictionary[int, Dictionary] = {}
var _undo_redo: EditorUndoRedoManager
var _path_changed: Callable
var _active_path_target_id := 0
var _active_path_node_id := 0


func _init() -> void:
	create_material("region", Color(0.28, 0.82, 0.72, 0.95))
	create_material("paint", Color(0.22, 0.72, 1.0, 0.9))
	create_material("disconnected", Color(0.48, 0.52, 0.58, 0.38))
	create_material("cursor", Color(0.35, 1.0, 0.45, 1.0))
	create_material("erase", Color(1.0, 0.28, 0.32, 1.0))
	create_handle_material("path_handles")


func configure(p_undo_redo: EditorUndoRedoManager, p_path_changed: Callable) -> void:
	_undo_redo = p_undo_redo
	_path_changed = p_path_changed


func set_active_path(target: MultiMeshInstance3D, node_id: int) -> void:
	# Editor hot reload can leave newly introduced script members as Nil on the
	# already-instantiated plugin. Normalizing here keeps the live editor usable.
	var previous := instance_from_id(int(_active_path_target_id)) as MultiMeshInstance3D
	_active_path_target_id = target.get_instance_id() if is_instance_valid(target) else 0
	_active_path_node_id = node_id
	if is_instance_valid(previous):
		previous.update_gizmos()
	if is_instance_valid(target):
		target.update_gizmos()


func _get_gizmo_name() -> String:
	return "Scatter Regions"


func _get_priority() -> int:
	return 1


func _has_gizmo(node_3d: Node3D) -> bool:
	return node_3d is MultiMeshInstance3D and ScatterGraphAttachment.get_graph(node_3d) != null


func set_brush_preview(
		target: MultiMeshInstance3D,
		position: Vector3,
		normal: Vector3,
		radius: float,
		erase: bool,
) -> void:
	if not is_instance_valid(target):
		return
	_brush_previews[target.get_instance_id()] = {
		"position": position,
		"normal": normal,
		"radius": radius,
		"erase": erase,
	}
	target.update_gizmos()


func clear_brush_preview(target: MultiMeshInstance3D) -> void:
	if not is_instance_valid(target):
		return
	_brush_previews.erase(target.get_instance_id())
	target.update_gizmos()


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var target := gizmo.get_node_3d() as MultiMeshInstance3D
	if not is_instance_valid(target):
		return
	var graph := ScatterGraphAttachment.get_graph(target)
	if graph == null:
		return
	var connected_ids := _connected_node_ids(graph)
	for node in graph.nodes:
		if not node.enabled or not node is ScatterRegionNode:
			continue
		var lines := node.get_preview_lines()
		if lines.is_empty():
			continue
		var material_name := "disconnected"
		if connected_ids.has(node.node_id):
			material_name = "paint" if node is ScatterPaintRegionNode else "region"
		gizmo.add_lines(lines, get_material(material_name, gizmo), false)
	var active_path := _active_path_for(target)
	if active_path != null and not active_path.points.is_empty():
		var ids := PackedInt32Array()
		for index in active_path.points.size():
			ids.append(index)
		gizmo.add_handles(active_path.points, get_material("path_handles", gizmo), ids)
	var preview: Dictionary = _brush_previews.get(target.get_instance_id(), {})
	if not preview.is_empty():
		var cursor_lines := ScatterBrushGeometry.circle(
			preview.position,
			preview.normal,
			preview.radius,
			true,
		)
		gizmo.add_lines(cursor_lines, get_material("erase" if preview.erase else "cursor", gizmo), false)


func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	var target := gizmo.get_node_3d() as MultiMeshInstance3D
	return tr("Path Point %d") % (handle_id + 1) if _active_path_for(target) != null else ""


func _get_handle_value(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> Variant:
	var target := gizmo.get_node_3d() as MultiMeshInstance3D
	var path := _active_path_for(target)
	return path.points.duplicate() if path != null else PackedVector3Array()


func _set_handle(
		gizmo: EditorNode3DGizmo,
		handle_id: int,
		_secondary: bool,
		camera: Camera3D,
		screen_position: Vector2,
) -> void:
	var target := gizmo.get_node_3d() as MultiMeshInstance3D
	var path := _active_path_for(target)
	if path == null or handle_id < 0 or handle_id >= path.points.size():
		return
	var current_world := target.to_global(path.points[handle_id])
	var plane_normal := camera.global_transform.basis.z.normalized()
	var drag_plane := Plane(plane_normal, plane_normal.dot(current_world))
	var world_position = drag_plane.intersects_ray(
		camera.project_ray_origin(screen_position),
		camera.project_ray_normal(screen_position),
	)
	if world_position == null:
		return
	var points := path.points.duplicate()
	points[handle_id] = target.to_local(world_position)
	path.points = points
	var graph := ScatterGraphAttachment.get_graph(target)
	if graph != null:
		graph.emit_changed()
	target.update_gizmos()


func _commit_handle(
		gizmo: EditorNode3DGizmo,
		_handle_id: int,
		_secondary: bool,
		restore: Variant,
		cancel: bool,
) -> void:
	var target := gizmo.get_node_3d() as MultiMeshInstance3D
	var path := _active_path_for(target)
	if path == null:
		return
	var previous: PackedVector3Array = restore
	if cancel:
		path.points = previous
		_finish_path_change(target)
		return
	var current := path.points.duplicate()
	if current == previous:
		return
	if _undo_redo == null:
		_finish_path_change(target)
		return
	_undo_redo.create_action(tr("Move Scatter Path Point"), UndoRedo.MERGE_DISABLE, target)
	_undo_redo.add_do_property(path, &"points", current)
	_undo_redo.add_undo_property(path, &"points", previous)
	_undo_redo.add_do_method(self, "_finish_path_change", target)
	_undo_redo.add_undo_method(self, "_finish_path_change", target)
	_undo_redo.commit_action(false)
	_finish_path_change(target)


func _active_path_for(target: MultiMeshInstance3D) -> ScatterPathNode:
	if not is_instance_valid(target) or target.get_instance_id() != int(_active_path_target_id):
		return null
	var graph := ScatterGraphAttachment.get_graph(target)
	return graph.find_node(int(_active_path_node_id)) as ScatterPathNode if graph != null else null


func _finish_path_change(target: MultiMeshInstance3D) -> void:
	if not is_instance_valid(target):
		return
	var graph := ScatterGraphAttachment.get_graph(target)
	if graph != null:
		graph.emit_changed()
	target.update_gizmos()
	if _path_changed.is_valid():
		_path_changed.call()


func _connected_node_ids(graph: ScatterGraph) -> Dictionary[int, bool]:
	var result: Dictionary[int, bool] = {}
	var output := graph.final_output_node()
	if output == null:
		return result
	var pending: Array[int] = [output.node_id]
	while not pending.is_empty():
		var node_id := pending.pop_back()
		if result.has(node_id):
			continue
		result[node_id] = true
		for connection in graph.connections:
			if connection.to_node_id == node_id:
				pending.append(connection.from_node_id)
	return result
