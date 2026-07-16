@tool
extends EditorPlugin

const PanelScript := preload("res://addons/scatter/editor/ui/scatter_panel.gd")
const InspectorScript := preload("res://addons/scatter/editor/inspector/scatter_inspector_plugin.gd")
const GizmoScript := preload("res://addons/scatter/editor/gizmo/scatter_gizmo_plugin.gd")
const ViewportToolHostScript := preload("res://addons/scatter/editor/viewport/scatter_viewport_tool_host.gd")

var _panel: ScatterPanel
var _inspector: ScatterInspectorPlugin
var _target: MultiMeshInstance3D
var _gizmo: ScatterGizmoPlugin
var _viewport_tools: ScatterViewportToolHost
var _build_coordinator: ScatterBuildCoordinator
var _recipe_links: ScatterRecipeLinkController


func _enter_tree() -> void:
	ScatterBuiltinRegistry.register_all()
	_recipe_links = ScatterRecipeLinkController.new(get_undo_redo())
	_recipe_links.changed.connect(_recipe_link_changed)
	_panel = PanelScript.new()
	_panel.set_undo_redo(get_undo_redo())
	_panel.set_recipe_link_controller(_recipe_links)
	add_control_to_bottom_panel(_panel, tr("Scatter"))
	_panel.build_requested.connect(_build_current)
	_panel.recipe_changed.connect(_recipe_changed)
	_panel.target_requested.connect(_open_target)
	_panel.viewport_tool_changed.connect(_viewport_tool_changed)
	scene_closed.connect(_scene_closed)
	_inspector = InspectorScript.new()
	_inspector.open_requested.connect(_open_target)
	_inspector.rebuild_requested.connect(_build_target)
	_inspector.detach_requested.connect(_detach_target)
	_inspector.configure_requested.connect(_configure_target)
	_inspector.load_requested.connect(_load_target_recipe)
	add_inspector_plugin(_inspector)
	_gizmo = GizmoScript.new()
	_gizmo.configure(get_undo_redo(), _panel.notify_viewport_data_changed, _panel.get_graph_for_build)
	add_node_3d_gizmo_plugin(_gizmo)
	_viewport_tools = ViewportToolHostScript.new()
	_viewport_tools.configure(self, _panel, _gizmo, get_undo_redo())
	_build_coordinator = ScatterBuildCoordinator.new(_panel.get_graph_for_build)
	_build_coordinator.build_succeeded.connect(_build_succeeded)
	_build_coordinator.build_failed.connect(_build_failed)


func _exit_tree() -> void:
	if _build_coordinator != null:
		_build_coordinator.shutdown()
	_build_coordinator = null
	_recipe_links = null
	if _viewport_tools != null:
		_viewport_tools.shutdown()
		_viewport_tools = null
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
		var target_changed := _target != object
		_target = object
		_panel.set_target(_target)
		_viewport_tools.set_target(_target)
		if target_changed and _gizmo != null:
			_gizmo.refresh_target(_target, true)
	else:
		_target = null
		_panel.set_target(null)
		_viewport_tools.set_target(null)


func _make_visible(visible: bool) -> void:
	if visible and is_instance_valid(_target):
		make_bottom_panel_item_visible(_panel)
	elif not visible:
		_panel.stop_viewport_editing()


func _open_target(target: MultiMeshInstance3D) -> void:
	_target = target
	_panel.set_target(target)
	_viewport_tools.set_target(target)
	make_bottom_panel_item_visible(_panel)
	get_editor_interface().edit_node(target)


func _configure_target(target: MultiMeshInstance3D) -> void:
	_open_target(target)
	_panel.configure_recipe()


func _load_target_recipe(target: MultiMeshInstance3D) -> void:
	_open_target(target)
	_panel.load_recipe()


func _scene_closed(filepath: String) -> void:
	if _panel != null and _panel.close_scene_sessions(filepath):
		_target = null
		if _viewport_tools != null:
			_viewport_tools.set_target(null)


func _build_current() -> void:
	if is_instance_valid(_target):
		_build_target(_target)


func _build_target(target: MultiMeshInstance3D, mark_unsaved := true) -> void:
	if _build_coordinator != null:
		_build_coordinator.build(target, get_editor_interface().get_edited_scene_root(), mark_unsaved)


func _build_succeeded(target: MultiMeshInstance3D, result: ScatterBuildResult, mark_unsaved: bool) -> void:
	if _panel.target == target:
		_panel.update_output_counts(result.output_counts)
		if not result.warnings.is_empty():
			_panel.update_status(tr("Built %d instances with %d warning(s): %s") % [
				result.instances.transforms.size(),
				result.warnings.size(),
				result.warnings[0].message,
			])
	_mark_scene_changed(mark_unsaved, target)


func _build_failed(target: MultiMeshInstance3D, result: ScatterBuildResult) -> void:
	if _panel.target == target:
		_panel.update_status(tr("Build failed: %s") % result.error)
	push_error("Scatter: %s" % result.error)


func _detach_target(target: MultiMeshInstance3D) -> void:
	if _recipe_links != null:
		_recipe_links.detach(target, tr("Detach Scatter Recipe"))


func _viewport_tool_changed(tool_id: StringName, _node_id: int) -> void:
	_gizmo.set_active_node(_target, _node_id)
	_viewport_tools.select(tool_id, _node_id)


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	return _viewport_tools.forward_3d_gui_input(camera, event) if _viewport_tools != null else EditorPlugin.AFTER_GUI_INPUT_PASS


func _mark_scene_changed(
		mark_unsaved := true,
		changed_target: MultiMeshInstance3D = null,
) -> void:
	if mark_unsaved and get_editor_interface().has_method("mark_scene_as_unsaved"):
		get_editor_interface().mark_scene_as_unsaved()
	var target_to_refresh := changed_target if is_instance_valid(changed_target) else _target
	if is_instance_valid(target_to_refresh):
		target_to_refresh.notify_property_list_changed()
		target_to_refresh.update_gizmos()


func _recipe_changed() -> void:
	if is_instance_valid(_target):
		_target.notify_property_list_changed()
		_target.update_gizmos()


func _recipe_link_changed(target: MultiMeshInstance3D) -> void:
	if _gizmo != null:
		_gizmo.refresh_target(target, true)
	_mark_scene_changed(false, target)
