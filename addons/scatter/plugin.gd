@tool
extends EditorPlugin

const PanelScript := preload("res://addons/scatter/scatter_panel.gd")
const InspectorScript := preload("res://addons/scatter/scatter_inspector.gd")
const GizmoScript := preload("res://addons/scatter/scatter_gizmo.gd")

var _panel: ScatterPanel
var _inspector: ScatterInspector
var _bottom_button: Button
var _target: MultiMeshInstance3D
var _gizmo: ScatterGizmoPlugin
var _last_paint_position := Vector3.INF


func _enter_tree() -> void:
	_panel = PanelScript.new()
	_panel.name = "ScatterEditor"
	_bottom_button = add_control_to_bottom_panel(_panel, "Scatter")
	_panel.build_requested.connect(_build_current)
	_panel.recipe_changed.connect(_mark_scene_changed)
	_panel.paint_mode_changed.connect(_on_paint_mode_changed)
	_inspector = InspectorScript.new()
	_inspector.open_requested.connect(_open_target)
	_inspector.rebuild_requested.connect(_build_target)
	_inspector.detach_requested.connect(_detach_target)
	add_inspector_plugin(_inspector)
	_gizmo = GizmoScript.new()
	add_node_3d_gizmo_plugin(_gizmo)


func _exit_tree() -> void:
	if is_instance_valid(_target) and _gizmo != null:
		_gizmo.clear_brush_preview(_target)
	_target = null
	if _gizmo != null:
		remove_node_3d_gizmo_plugin(_gizmo)
		_gizmo = null
	if _inspector != null:
		remove_inspector_plugin(_inspector)
		_inspector = null
	if _panel != null:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null


func _handles(object: Object) -> bool:
	return object is MultiMeshInstance3D


func _edit(object: Object) -> void:
	if is_instance_valid(_target) and _target != object and _gizmo != null:
		_gizmo.clear_brush_preview(_target)
	if object is MultiMeshInstance3D:
		_target = object
		_panel.set_target(_target)
	else:
		_target = null
		_panel.set_target(null)


func _make_visible(visible: bool) -> void:
	if visible and is_instance_valid(_target):
		make_bottom_panel_item_visible(_panel)
	elif not visible and _panel.paint_active:
		_panel.stop_painting()


func _open_target(target: MultiMeshInstance3D) -> void:
	_target = target
	_panel.set_target(target)
	make_bottom_panel_item_visible(_panel)
	get_editor_interface().edit_node(target)
	_mark_scene_changed()


func _build_current() -> void:
	if is_instance_valid(_target):
		_build_target(_target)


func _build_target(target: MultiMeshInstance3D) -> void:
	var queue: Array[MultiMeshInstance3D] = [target]
	var visited := {}
	while not queue.is_empty():
		var current := queue.pop_front()
		if not is_instance_valid(current) or visited.has(current.get_instance_id()): continue
		visited[current.get_instance_id()] = true
		_build_one(current)
		for dependent in _find_dependents(current):
			if not visited.has(dependent.get_instance_id()): queue.append(dependent)


func _build_one(target: MultiMeshInstance3D) -> void:
	var config := ScatterGenerator.ensure_config(target)
	var result := ScatterGenerator.build(target, config)
	if not result.get("ok", false):
		if _panel.target == target: _panel.update_status("Build failed: %s" % result.get("error", "Unknown error"))
		push_error("Scatter: %s" % result.get("error", "Unknown error"))
		return
	ScatterGenerator.apply_to_multimesh(target, result)
	if _panel.target == target: _panel.update_status()
	_mark_scene_changed()


func _find_dependents(source: MultiMeshInstance3D) -> Array[MultiMeshInstance3D]:
	var result: Array[MultiMeshInstance3D] = []
	var root := get_editor_interface().get_edited_scene_root()
	if not is_instance_valid(root): return result
	var candidates: Array[Node] = [root]
	while not candidates.is_empty():
		var candidate := candidates.pop_front()
		candidates.append_array(candidate.get_children())
		if not candidate is MultiMeshInstance3D or not candidate.has_meta(ScatterGenerator.META_KEY): continue
		var recipe = candidate.get_meta(ScatterGenerator.META_KEY)
		if not recipe is ScatterConfig: continue
		for entry in recipe.nodes:
			if entry.get("enabled", true) and entry.get("type", "") == "proxy" and entry.get("params", {}).get("auto_rebuild", true):
				if candidate.get_node_or_null(entry.get("params", {}).get("scatter_node", NodePath())) == source:
					result.append(candidate)
					break
	return result


func _detach_target(target: MultiMeshInstance3D) -> void:
	if not target.has_meta(ScatterGenerator.META_KEY): return
	var recipe = target.get_meta(ScatterGenerator.META_KEY)
	var undo := get_undo_redo()
	undo.create_action("Detach Scatter Recipe")
	undo.add_do_method(target, "remove_meta", ScatterGenerator.META_KEY)
	undo.add_undo_method(target, "set_meta", ScatterGenerator.META_KEY, recipe)
	undo.add_do_method(self, "_refresh_after_metadata_change", target)
	undo.add_undo_method(self, "_refresh_after_metadata_change", target)
	undo.commit_action()


func _refresh_after_metadata_change(target: MultiMeshInstance3D) -> void:
	if _panel.target == target:
		_panel.set_target(target)
	target.notify_property_list_changed()
	_mark_scene_changed()


func _on_paint_mode_changed(active: bool) -> void:
	_last_paint_position = Vector3.INF
	if active:
		make_bottom_panel_item_visible(_panel)
	elif is_instance_valid(_target) and _gizmo != null:
		_gizmo.clear_brush_preview(_target)


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not is_instance_valid(_target) or not _panel.paint_active:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseMotion:
		_update_brush_preview(camera, event.position)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_paint_at_screen(camera, event.position, true)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_paint_at_screen(camera, event.position)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _brush_hit(camera: Camera3D, screen_position: Vector2) -> Dictionary:
	if not _target.is_inside_tree() or _target.get_world_3d() == null: return {}
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100000.0, _panel.config.collision_mask)
	return _target.get_world_3d().direct_space_state.intersect_ray(query)


func _update_brush_preview(camera: Camera3D, screen_position: Vector2) -> void:
	var hit := _brush_hit(camera, screen_position)
	if hit.is_empty():
		_gizmo.clear_brush_preview(_target)
		return
	var local_position := _target.to_local(hit.position)
	var local_normal := (_target.global_transform.basis.inverse() * Vector3(hit.normal)).normalized()
	_gizmo.set_brush_preview(_target, local_position, local_normal, _panel.brush_radius, _panel.paint_erase)


func _paint_at_screen(camera: Camera3D, screen_position: Vector2, dragging := false) -> void:
	var paint_entry := _panel.get_active_paint_entry()
	if paint_entry.is_empty(): return
	var hit := _brush_hit(camera, screen_position)
	if hit.is_empty(): return
	var local_position := _target.to_local(hit.position)
	if dragging and _last_paint_position != Vector3.INF and _last_paint_position.distance_to(local_position) < _panel.brush_radius * 0.35:
		return
	_last_paint_position = local_position
	var local_normal := (_target.global_transform.basis.inverse() * Vector3(hit.normal)).normalized()
	var old_strokes: Array = Array(paint_entry.get("params", {}).get("strokes", [])).duplicate(true)
	var new_strokes := old_strokes.duplicate(true)
	if _panel.paint_erase:
		for i in range(new_strokes.size() - 1, -1, -1):
			var stroke: Dictionary = new_strokes[i]
			var erase_radius := _panel.brush_radius + float(stroke.get("radius", 0.0)) * 0.35
			if Vector3(stroke.get("position", Vector3.ZERO)).distance_to(local_position) <= erase_radius:
				new_strokes.remove_at(i)
	else:
		new_strokes.append({"position": local_position, "normal": local_normal, "radius": _panel.brush_radius})
	_commit_paint_change(int(paint_entry.id), old_strokes, new_strokes, "擦除 Scatter 绘制区域" if _panel.paint_erase else "绘制 Scatter 区域")
	_gizmo.set_brush_preview(_target, local_position, local_normal, _panel.brush_radius, _panel.paint_erase)


func _commit_paint_change(node_id: int, old_strokes: Array, new_strokes: Array, action_name: String) -> void:
	var undo := get_undo_redo()
	undo.create_action(action_name, UndoRedo.MERGE_ENDS if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else UndoRedo.MERGE_DISABLE)
	undo.add_do_method(self, "_set_paint_strokes", _target, node_id, new_strokes)
	undo.add_undo_method(self, "_set_paint_strokes", _target, node_id, old_strokes)
	undo.commit_action()


func _set_paint_strokes(target: MultiMeshInstance3D, node_id: int, strokes: Array) -> void:
	if not is_instance_valid(target): return
	var config := ScatterGenerator.ensure_config(target)
	var entry := config.find_node(node_id)
	if entry.is_empty() or entry.get("type", "") != "paint_region": return
	entry.params.strokes = strokes.duplicate(true)
	config.emit_changed()
	if _panel.target == target: _panel.refresh_paint_count(node_id)
	_build_target(target)


func _mark_scene_changed() -> void:
	if get_editor_interface().has_method("mark_scene_as_unsaved"):
		get_editor_interface().mark_scene_as_unsaved()
	if is_instance_valid(_target):
		_target.notify_property_list_changed()
		_target.update_gizmos()
