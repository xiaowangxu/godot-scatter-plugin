@tool
extends EditorPlugin

const PanelScript := preload("res://addons/scatter/editor/scatter_panel.gd")
const InspectorScript := preload("res://addons/scatter/editor/inspector/scatter_inspector_plugin.gd")
const GizmoScript := preload("res://addons/scatter/editor/gizmo/scatter_gizmo_plugin.gd")
const PaintToolScript := preload("res://addons/scatter/editor/paint/scatter_paint_tool.gd")
const PathToolScript := preload("res://addons/scatter/editor/paint/scatter_path_tool.gd")

var _panel: ScatterPanel
var _inspector: ScatterInspectorPlugin
var _bottom_button: Button
var _target: MultiMeshInstance3D
var _gizmo: ScatterGizmoPlugin
var _paint_tool: ScatterPaintTool
var _path_tool: ScatterPathTool
var _paint_toolbar: Control
var _path_toolbar: Control


func _enter_tree() -> void:
	ScatterBuiltinRegistry.register_all()
	_panel = PanelScript.new()
	_panel.set_undo_redo(get_undo_redo())
	_bottom_button = add_control_to_bottom_panel(_panel, tr("Scatter"))
	_panel.build_requested.connect(_build_current)
	_panel.recipe_changed.connect(_recipe_changed)
	_panel.viewport_tool_changed.connect(_viewport_tool_changed)
	_inspector = InspectorScript.new()
	_inspector.open_requested.connect(_open_target)
	_inspector.rebuild_requested.connect(_build_target)
	_inspector.detach_requested.connect(_detach_target)
	_inspector.configure_requested.connect(_configure_target)
	_inspector.load_requested.connect(_load_target_recipe)
	add_inspector_plugin(_inspector)
	_gizmo = GizmoScript.new()
	_gizmo.configure(get_undo_redo(), _panel._path_data_changed)
	add_node_3d_gizmo_plugin(_gizmo)
	_paint_tool = PaintToolScript.new()
	_paint_tool.configure(_panel, _gizmo, get_undo_redo(), _build_current, _mark_scene_changed)
	_paint_toolbar = _paint_tool.get_toolbar()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _paint_toolbar)
	_path_tool = PathToolScript.new()
	_path_tool.configure(_gizmo, get_undo_redo(), _panel._path_data_changed)
	_path_toolbar = _path_tool.get_toolbar()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _path_toolbar)


func _exit_tree() -> void:
	if _paint_tool != null:
		_paint_tool.stop()
		_paint_tool = null
	if _paint_toolbar != null:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _paint_toolbar)
		_paint_toolbar.queue_free()
		_paint_toolbar = null
	if _path_tool != null:
		_path_tool.deactivate()
		_path_tool = null
	if _path_toolbar != null:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _path_toolbar)
		_path_toolbar.queue_free()
		_path_toolbar = null
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
	ScatterBuiltinRegistry.unregister_all()


func _handles(object: Object) -> bool:
	return object is MultiMeshInstance3D


func _edit(object: Object) -> void:
	if object is MultiMeshInstance3D:
		_target = object
		_panel.set_target(_target)
		_paint_tool.set_target(_target)
	else:
		_target = null
		_panel.set_target(null)
		_paint_tool.set_target(null)


func _make_visible(visible: bool) -> void:
	if visible and is_instance_valid(_target):
		make_bottom_panel_item_visible(_panel)
	elif not visible:
		_panel.stop_viewport_editing()


func _open_target(target: MultiMeshInstance3D) -> void:
	_target = target
	_panel.set_target(target)
	_paint_tool.set_target(target)
	make_bottom_panel_item_visible(_panel)
	get_editor_interface().edit_node(target)


func _configure_target(target: MultiMeshInstance3D) -> void:
	_open_target(target)
	_panel.configure_recipe()


func _load_target_recipe(target: MultiMeshInstance3D) -> void:
	_open_target(target)
	_panel.load_recipe()


func _build_current() -> void:
	if is_instance_valid(_target):
		_build_target(_target)


func _build_target(target: MultiMeshInstance3D, mark_unsaved := true) -> void:
	var queue: Array[MultiMeshInstance3D] = [target]
	var visited: Dictionary[int, bool] = {}
	while not queue.is_empty():
		var current := queue.pop_front()
		if not is_instance_valid(current) or visited.has(current.get_instance_id()):
			continue
		visited[current.get_instance_id()] = true
		_build_one(current, mark_unsaved)
		for dependent in _find_dependents(current):
			if not visited.has(dependent.get_instance_id()):
				queue.append(dependent)


func _build_one(target: MultiMeshInstance3D, mark_unsaved := true) -> void:
	var graph := _panel.get_graph_for_build(target)
	if graph == null:
		return
	var result := ScatterBuildService.build_target(target, graph)
	if not result.ok:
		if _panel.target == target:
			_panel.update_status(tr("Build failed: %s") % result.error)
		push_error("Scatter: %s" % result.error)
		return
	ScatterMultiMeshWriter.apply(target, result)
	if _panel.target == target:
		_panel.update_group_counts(result.group_counts)
	target.update_gizmos()
	_mark_scene_changed(mark_unsaved)


func _find_dependents(source: MultiMeshInstance3D) -> Array[MultiMeshInstance3D]:
	var result: Array[MultiMeshInstance3D] = []
	var root := get_editor_interface().get_edited_scene_root()
	if not is_instance_valid(root):
		return result
	var candidates: Array[Node] = [root]
	while not candidates.is_empty():
		var candidate := candidates.pop_front()
		candidates.append_array(candidate.get_children())
		if not candidate is MultiMeshInstance3D:
			continue
		var graph := _panel.get_graph_for_build(candidate)
		if graph == null:
			continue
		for node in graph.nodes:
			if (
				node is ScatterProxyNode
				and node.enabled
				and node.auto_rebuild
				and candidate.get_node_or_null(node.scatter_node) == source
			):
				result.append(candidate)
				break
	return result


func _detach_target(target: MultiMeshInstance3D) -> void:
	var graph := ScatterGraphAttachment.get_graph(target)
	if graph == null:
		return
	var undo := get_undo_redo()
	undo.create_action(tr("Detach Scatter Recipe"), UndoRedo.MERGE_DISABLE, target)
	undo.add_do_method(self, "_detach_graph", target)
	undo.add_undo_method(self, "_attach_graph", target, graph)
	undo.add_do_method(self, "_refresh_after_metadata_change", target)
	undo.add_undo_method(self, "_refresh_after_metadata_change", target)
	undo.commit_action()


func _detach_graph(target: MultiMeshInstance3D) -> void:
	ScatterGraphAttachment.detach(target)


func _attach_graph(target: MultiMeshInstance3D, graph: ScatterGraph) -> void:
	ScatterGraphAttachment.attach(target, graph)


func _refresh_after_metadata_change(target: MultiMeshInstance3D) -> void:
	if _panel.target == target:
		_panel.set_target(null)
		_panel.set_target(target)
	target.notify_property_list_changed()
	_mark_scene_changed(false)


func _viewport_tool_changed(tool_id: StringName, _node_id: int) -> void:
	if tool_id == &"path":
		_paint_tool.stop()
		_path_tool.activate(_target, _panel.get_active_path_node())
		make_bottom_panel_item_visible(_panel)
	else:
		_path_tool.deactivate()
	if tool_id == &"paint":
		_paint_tool.activate()
		make_bottom_panel_item_visible(_panel)
	else:
		_paint_tool.stop()


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _paint_tool == null or _path_tool == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var path_result := _path_tool.forward_3d_gui_input(camera, event)
	if path_result == EditorPlugin.AFTER_GUI_INPUT_STOP:
		return path_result
	return _paint_tool.forward_3d_gui_input(camera, event)


func _mark_scene_changed(mark_unsaved := true) -> void:
	if mark_unsaved and get_editor_interface().has_method("mark_scene_as_unsaved"):
		get_editor_interface().mark_scene_as_unsaved()
	if is_instance_valid(_target):
		_target.notify_property_list_changed()
		_target.update_gizmos()


func _recipe_changed() -> void:
	if is_instance_valid(_target):
		_target.notify_property_list_changed()
		_target.update_gizmos()
