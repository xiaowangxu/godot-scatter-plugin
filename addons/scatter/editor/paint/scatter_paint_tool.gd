@tool
class_name ScatterPaintTool
extends RefCounted

var panel: ScatterPanel
var gizmo: ScatterGizmoPlugin
var undo_redo: EditorUndoRedoManager
var target: MultiMeshInstance3D
var build_requested: Callable
var scene_changed: Callable
var _last_paint_position := Vector3.INF


func configure(
		p_panel: ScatterPanel,
		p_gizmo: ScatterGizmoPlugin,
		p_undo_redo: EditorUndoRedoManager,
		p_build_requested: Callable,
		p_scene_changed: Callable,
) -> void:
	panel = p_panel
	gizmo = p_gizmo
	undo_redo = p_undo_redo
	build_requested = p_build_requested
	scene_changed = p_scene_changed


func set_target(value: MultiMeshInstance3D) -> void:
	if is_instance_valid(target) and target != value and gizmo != null:
		gizmo.clear_brush_preview(target)
	target = value
	reset_stroke()


func reset_stroke() -> void:
	_last_paint_position = Vector3.INF


func stop() -> void:
	reset_stroke()
	if is_instance_valid(target) and gizmo != null:
		gizmo.clear_brush_preview(target)


func forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not is_instance_valid(target) or panel == null or not panel.paint_active:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseMotion:
		_update_brush_preview(camera, event.position)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_paint_at_screen(camera, event.position, true)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			reset_stroke()
			_paint_at_screen(camera, event.position)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		reset_stroke()
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _brush_hit(camera: Camera3D, screen_position: Vector2) -> Dictionary:
	if not target.is_inside_tree() or target.get_world_3d() == null:
		return {}
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var mask: int = panel.graph.collision_mask if panel.graph != null else 1
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100000.0, mask)
	return target.get_world_3d().direct_space_state.intersect_ray(query)


func _update_brush_preview(camera: Camera3D, screen_position: Vector2) -> void:
	var hit := _brush_hit(camera, screen_position)
	if hit.is_empty():
		gizmo.clear_brush_preview(target)
		return
	var local_position := target.to_local(hit.position)
	var local_normal := (target.global_transform.basis.inverse() * Vector3(hit.normal)).normalized()
	gizmo.set_brush_preview(target, local_position, local_normal, panel.brush_radius, panel.paint_erase)


func _paint_at_screen(camera: Camera3D, screen_position: Vector2, dragging := false) -> void:
	var paint_node: ScatterPaintRegionNode = panel.get_active_paint_node()
	if paint_node == null:
		return
	var hit := _brush_hit(camera, screen_position)
	if hit.is_empty():
		return
	var local_position := target.to_local(hit.position)
	if (
		dragging
		and _last_paint_position != Vector3.INF
		and _last_paint_position.distance_to(local_position) < panel.brush_radius * 0.35
	):
		return
	_last_paint_position = local_position
	var local_normal := (target.global_transform.basis.inverse() * Vector3(hit.normal)).normalized()
	var next_strokes: Array[ScatterPaintStroke] = paint_node.strokes.duplicate()
	if panel.paint_erase:
		for index in range(next_strokes.size() - 1, -1, -1):
			var stroke := next_strokes[index]
			var erase_radius := panel.brush_radius + stroke.radius * 0.35
			if stroke.position.distance_to(local_position) <= erase_radius:
				next_strokes.remove_at(index)
	else:
		next_strokes.append(ScatterPaintStroke.create(local_position, local_normal, panel.brush_radius))
	var undo := ScatterUndoService.new(undo_redo, target, _paint_data_changed)
	undo.commit_property(
		paint_node,
		&"strokes",
		next_strokes,
		tr("Erase Scatter Paint") if panel.paint_erase else tr("Paint Scatter Region"),
		"stroke",
		UndoRedo.MERGE_ENDS if dragging else UndoRedo.MERGE_DISABLE,
	)
	gizmo.set_brush_preview(target, local_position, local_normal, panel.brush_radius, panel.paint_erase)


func _paint_data_changed() -> void:
	if panel != null:
		panel._paint_data_changed()
	if scene_changed.is_valid():
		scene_changed.call(false)
