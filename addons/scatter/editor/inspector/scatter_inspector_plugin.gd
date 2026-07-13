@tool
class_name ScatterInspectorPlugin
extends EditorInspectorPlugin

signal open_requested(target: MultiMeshInstance3D)
signal rebuild_requested(target: MultiMeshInstance3D)
signal detach_requested(target: MultiMeshInstance3D)


func _can_handle(object: Object) -> bool:
	return object is MultiMeshInstance3D


func _parse_begin(object: Object) -> void:
	var target := object as MultiMeshInstance3D
	var has_graph := ScatterGraphAttachment.get_graph(target) != null
	var panel := VBoxContainer.new()
	var header := HBoxContainer.new()
	var label := Label.new()
	label.text = tr("Scatter Graph")
	label.tooltip_text = tr("Editor-only instance generation attached directly to this MultiMeshInstance3D.")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var badge := Label.new()
	badge.text = tr("Configured") if has_graph else tr("Not Configured")
	badge.modulate = Color("78c69a") if has_graph else Color("a5abb5")
	header.add_child(badge)
	panel.add_child(header)
	var actions := HBoxContainer.new()
	var open := Button.new()
	open.text = tr("Open Scatter Editor")
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open.tooltip_text = tr("Open the graph editor for this MultiMeshInstance3D.")
	open.pressed.connect(func(): open_requested.emit(target))
	actions.add_child(open)
	var rebuild := Button.new()
	rebuild.text = tr("Build")
	rebuild.disabled = not has_graph
	rebuild.tooltip_text = tr("Evaluate the graph and update the saved MultiMesh buffer.")
	rebuild.pressed.connect(func(): rebuild_requested.emit(target))
	actions.add_child(rebuild)
	panel.add_child(actions)
	if has_graph:
		var detach := Button.new()
		detach.text = tr("Detach Recipe (Keep Instances)")
		detach.flat = true
		detach.tooltip_text = tr("Remove the Scatter graph while preserving the current MultiMesh buffer.")
		detach.pressed.connect(func(): detach_requested.emit(target))
		panel.add_child(detach)
	add_custom_control(panel)
