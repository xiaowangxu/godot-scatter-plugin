@tool
class_name ScatterPlugin
extends RefCounted

var _host: EditorPlugin
var _panel: ScatterPanel
var _inspector: ScatterInspectorPlugin
var _gizmo: ScatterGizmoPlugin
var _viewport_tools: ScatterViewportToolHost
var _build_coordinator: ScatterBuildCoordinator
var _recipe_links: ScatterRecipeLinkController
var _target: MultiMeshInstance3D
var _signal_bindings: Array = []


func configure(
		host: EditorPlugin,
		panel: ScatterPanel,
		inspector: ScatterInspectorPlugin,
		gizmo: ScatterGizmoPlugin,
		viewport_tools: ScatterViewportToolHost,
		build_coordinator: ScatterBuildCoordinator,
		recipe_links: ScatterRecipeLinkController,
) -> void:
	shutdown()
	_host = host
	_panel = panel
	_inspector = inspector
	_gizmo = gizmo
	_viewport_tools = viewport_tools
	_build_coordinator = build_coordinator
	_recipe_links = recipe_links
	_bind_signals()


func shutdown() -> void:
	for binding in _signal_bindings:
		var source_signal: Signal = binding[0]
		var callback: Callable = binding[1]
		if source_signal.is_connected(callback):
			source_signal.disconnect(callback)
	_signal_bindings.clear()
	_target = null
	_host = null
	_panel = null
	_inspector = null
	_gizmo = null
	_viewport_tools = null
	_build_coordinator = null
	_recipe_links = null


func edit(object: Object) -> void:
	if object is MultiMeshInstance3D:
		var target_changed := _target != object
		_target = object
		_panel.set_target(_target)
		_viewport_tools.set_target(_target)
		if target_changed:
			_gizmo.refresh_target(_target, true)
	else:
		_target = null
		_panel.set_target(null)
		_viewport_tools.set_target(null)


func make_visible(visible: bool) -> void:
	if visible and is_instance_valid(_target):
		_host.make_bottom_panel_item_visible(_panel)
	elif not visible:
		_panel.stop_viewport_editing()


func forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	return (
		_viewport_tools.forward_3d_gui_input(camera, event)
		if _viewport_tools != null
		else EditorPlugin.AFTER_GUI_INPUT_PASS
	)


func _bind_signals() -> void:
	_bind(_panel.build_requested, _build_current)
	_bind(_panel.recipe_changed, _recipe_changed)
	_bind(_panel.target_requested, _open_target)
	_bind(_panel.target_invalidated, _target_invalidated)
	_bind(_panel.viewport_tool_changed, _viewport_tool_changed)
	_bind(_host.scene_closed, _scene_closed)
	_bind(_host.get_tree().node_added, _target_tree_changed)
	_bind(_host.get_tree().node_removed, _target_tree_changed)
	_bind(_inspector.open_requested, _open_target)
	_bind(_inspector.rebuild_requested, _build_target)
	_bind(_inspector.detach_requested, _detach_target)
	_bind(_inspector.configure_requested, _configure_target)
	_bind(_inspector.load_requested, _load_target_recipe)
	_bind(_build_coordinator.build_succeeded, _build_succeeded)
	_bind(_build_coordinator.build_failed, _build_failed)
	_bind(_recipe_links.changed, _recipe_link_changed)


func _bind(source_signal: Signal, callback: Callable) -> void:
	if source_signal.is_connected(callback):
		return
	source_signal.connect(callback)
	_signal_bindings.append([source_signal, callback])


func _open_target(target: MultiMeshInstance3D) -> void:
	_target = target
	_panel.set_target(target)
	_viewport_tools.set_target(target)
	_host.make_bottom_panel_item_visible(_panel)
	_host.get_editor_interface().edit_node(target)


func _configure_target(target: MultiMeshInstance3D) -> void:
	_open_target(target)
	_panel.configure_recipe()


func _load_target_recipe(target: MultiMeshInstance3D) -> void:
	_open_target(target)
	_panel.load_recipe()


func _scene_closed(filepath: String) -> void:
	if _panel.close_scene_sessions(filepath):
		_target = null
		_viewport_tools.set_target(null)


func _target_tree_changed(node: Node) -> void:
	if node is MultiMeshInstance3D:
		_panel.queue_target_presence_reconciliation(node)


func _target_invalidated(target_instance_id: int) -> void:
	if not is_instance_valid(_target) or _target.get_instance_id() == target_instance_id:
		_target = null
		_viewport_tools.set_target(null)


func _build_current() -> void:
	if is_instance_valid(_target):
		_build_target(_target)


func _build_target(target: MultiMeshInstance3D, mark_unsaved := true) -> void:
	_build_coordinator.build(target, mark_unsaved)


func _build_succeeded(
		target: MultiMeshInstance3D,
		result: ScatterBuildResult,
	mark_unsaved: bool,
) -> void:
	if _panel.target == target:
		_panel.update_diagnostics(result.errors, result.warnings)
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
		_panel.update_diagnostics(result.errors, result.warnings)
		_panel.update_status(tr("Build failed: %s") % result.error)
	push_error("Scatter: %s" % result.error)


func _detach_target(target: MultiMeshInstance3D) -> void:
	_recipe_links.detach(target, tr("Detach Scatter Recipe"))


func _viewport_tool_changed(tool_id: StringName, node_id: int) -> void:
	_gizmo.set_active_node(_target, node_id)
	_viewport_tools.select(tool_id, node_id)


func _mark_scene_changed(
		mark_unsaved := true,
		changed_target: MultiMeshInstance3D = null,
) -> void:
	if mark_unsaved and _host.get_editor_interface().has_method("mark_scene_as_unsaved"):
		_host.get_editor_interface().mark_scene_as_unsaved()
	var target_to_refresh := changed_target if is_instance_valid(changed_target) else _target
	if is_instance_valid(target_to_refresh):
		target_to_refresh.notify_property_list_changed()
		target_to_refresh.update_gizmos()


func _recipe_changed() -> void:
	if is_instance_valid(_target):
		_target.notify_property_list_changed()
		_target.update_gizmos()


func _recipe_link_changed(target: MultiMeshInstance3D) -> void:
	_gizmo.refresh_target(target, true)
	_mark_scene_changed(false, target)
