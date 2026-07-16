@tool
extends EditorPlugin

const PanelScript := preload("res://addons/scatter/editor/ui/scatter_panel.gd")
const InspectorScript := preload("res://addons/scatter/editor/inspector/scatter_inspector_plugin.gd")
const GizmoScript := preload("res://addons/scatter/editor/gizmo/scatter_gizmo_plugin.gd")
const ViewportToolHostScript := preload("res://addons/scatter/editor/viewport/scatter_viewport_tool_host.gd")
const ScatterPluginScript := preload("res://addons/scatter/editor/application/scatter_plugin.gd")

var _panel: ScatterPanel
var _inspector: ScatterInspectorPlugin
var _gizmo: ScatterGizmoPlugin
var _viewport_tools: ScatterViewportToolHost
var _build_coordinator: ScatterBuildCoordinator
var _recipe_links: ScatterRecipeLinkController
var _scatter_plugin: ScatterPlugin


func _enter_tree() -> void:
	ScatterBuiltinRegistry.register_all()
	_recipe_links = ScatterRecipeLinkController.new(get_undo_redo())
	_panel = PanelScript.new()
	_panel.set_undo_redo(get_undo_redo())
	_panel.set_recipe_link_controller(_recipe_links)
	add_control_to_bottom_panel(_panel, tr("Scatter"))
	_inspector = InspectorScript.new()
	add_inspector_plugin(_inspector)
	_gizmo = GizmoScript.new()
	_gizmo.configure(get_undo_redo(), _panel.notify_viewport_data_changed, _panel.get_graph_for_build)
	add_node_3d_gizmo_plugin(_gizmo)
	_viewport_tools = ViewportToolHostScript.new()
	_viewport_tools.configure(self, _panel, _gizmo, get_undo_redo())
	_build_coordinator = ScatterBuildCoordinator.new(_panel.get_graph_for_build)
	_scatter_plugin = ScatterPluginScript.new()
	_scatter_plugin.configure(
		self,
		_panel,
		_inspector,
		_gizmo,
		_viewport_tools,
		_build_coordinator,
		_recipe_links,
	)


func _exit_tree() -> void:
	if _scatter_plugin != null:
		_scatter_plugin.shutdown()
		_scatter_plugin = null
	if _build_coordinator != null:
		_build_coordinator.shutdown()
	_build_coordinator = null
	_recipe_links = null
	if _viewport_tools != null:
		_viewport_tools.shutdown()
		_viewport_tools = null
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
	if _scatter_plugin != null:
		_scatter_plugin.edit(object)


func _make_visible(visible: bool) -> void:
	if _scatter_plugin != null:
		_scatter_plugin.make_visible(visible)


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	return (
		_scatter_plugin.forward_3d_gui_input(camera, event)
		if _scatter_plugin != null
		else EditorPlugin.AFTER_GUI_INPUT_PASS
	)
