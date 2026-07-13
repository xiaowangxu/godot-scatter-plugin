@tool
class_name ScatterInspectorPlugin
extends EditorInspectorPlugin

signal open_requested(target: MultiMeshInstance3D)
signal rebuild_requested(target: MultiMeshInstance3D)
signal detach_requested(target: MultiMeshInstance3D)
signal configure_requested(target: MultiMeshInstance3D)
signal load_requested(target: MultiMeshInstance3D)


func _can_handle(object: Object) -> bool:
	return object is MultiMeshInstance3D


func _parse_begin(object: Object) -> void:
	var target := object as MultiMeshInstance3D
	var graph := ScatterGraphAttachment.get_graph(target)
	var has_graph := graph != null
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
	if not has_graph:
		var configure := Button.new()
		configure.text = tr("Configure Scatter")
		configure.tooltip_text = tr("Create a new linked Scatter recipe for this MultiMeshInstance3D.")
		configure.pressed.connect(func(): configure_requested.emit(target))
		panel.add_child(configure)
		var load := Button.new()
		load.text = tr("Load Scatter Recipe")
		load.tooltip_text = tr("Link an existing Scatter recipe resource to this MultiMeshInstance3D.")
		load.pressed.connect(func(): load_requested.emit(target))
		panel.add_child(load)
	else:
		var recipe_path := Label.new()
		recipe_path.text = graph.resource_path
		recipe_path.tooltip_text = graph.resource_path
		recipe_path.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		recipe_path.modulate = Color("a5abb5")
		panel.add_child(recipe_path)
		var actions := HBoxContainer.new()
		var open := Button.new()
		open.text = tr("Open Scatter Editor")
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open.tooltip_text = tr("Open the linked Scatter recipe in the graph editor.")
		open.pressed.connect(func(): open_requested.emit(target))
		actions.add_child(open)
		var rebuild := Button.new()
		rebuild.text = tr("Build")
		rebuild.tooltip_text = tr("Evaluate the graph and update the saved MultiMesh buffer.")
		rebuild.pressed.connect(func(): rebuild_requested.emit(target))
		actions.add_child(rebuild)
		panel.add_child(actions)
		var load := Button.new()
		load.text = tr("Load Different Recipe")
		load.flat = true
		load.tooltip_text = tr("Replace this recipe link with another Scatter recipe resource.")
		load.pressed.connect(func(): load_requested.emit(target))
		panel.add_child(load)
		var detach := Button.new()
		detach.text = tr("Detach Recipe (Keep Instances)")
		detach.flat = true
		detach.tooltip_text = tr("Remove the Scatter graph while preserving the current MultiMesh buffer.")
		detach.pressed.connect(func(): detach_requested.emit(target))
		panel.add_child(detach)
	add_custom_control(panel)
