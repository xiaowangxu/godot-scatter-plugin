@tool
extends SceneTree

const InspectorScript := preload("res://addons/scatter/editor/inspector/scatter_inspector_plugin.gd")
const GizmoScript := preload("res://addons/scatter/editor/gizmo/scatter_gizmo_plugin.gd")
const PaintToolScript := preload("res://addons/scatter/editor/tools/scatter_paint_tool.gd")
const PathToolScript := preload("res://addons/scatter/editor/tools/scatter_path_tool.gd")


class CallbackCounter:
	extends RefCounted

	var graph_changes := 0
	var builds := 0

	func graph_changed() -> void:
		graph_changes += 1

	func build_requested() -> void:
		builds += 1


func _init() -> void:
	ScatterBuiltinRegistry.register_all()
	var graph := ScatterGraphFactory.create_default()
	# Non-variadic connection order is not semantic and must be repaired when a
	# recipe working copy is opened.
	graph.connections[0].order = 7
	var target := MultiMeshInstance3D.new()
	var recipe_path := "user://scatter_oop_recipe_test.tres"
	assert(ScatterRecipeIO.save_graph(graph, recipe_path) == OK)
	assert(ScatterGraphAttachment.attach(target, graph))
	var link_target := MultiMeshInstance3D.new()
	var links := ScatterRecipeLinkController.new()
	var link_changes := [0]
	links.changed.connect(func(_changed_target: MultiMeshInstance3D): link_changes[0] += 1)
	links.link(link_target, graph)
	assert(ScatterGraphAttachment.get_graph(link_target) == graph)
	links.detach(link_target)
	assert(ScatterGraphAttachment.get_graph(link_target) == null)
	assert(link_changes[0] == 2)
	link_target.free()
	var counter := CallbackCounter.new()
	var controller := ScatterGraphController.new()
	var controller_context := ScatterEditorContext.new()
	controller_context.graph = graph
	controller_context.target = target
	controller_context.graph_changed = counter.graph_changed
	controller_context.build_requested = counter.build_requested
	controller.configure(controller_context, null)
	var moved_node := graph.nodes[0]
	var old_position := moved_node.graph_position
	controller.move_nodes({moved_node.node_id: {"from": old_position, "to": old_position + Vector2(20, 10)}})
	assert(counter.graph_changes == 1)
	assert(counter.builds == 0)
	var panel := ScatterPanel.new()
	root.add_child(panel)
	panel.set_target(target)
	await process_frame
	assert(panel.graph != graph)
	assert(panel.graph.nodes.size() == graph.nodes.size())
	graph = panel.graph
	assert(graph.connections[0].order == 0)
	assert(panel.get_node("WorkArea/RecipeSidebar") is ScatterRecipeSidebar)
	var sidebar := panel.get_node("WorkArea/RecipeSidebar") as ScatterRecipeSidebar
	assert(sidebar.recipe_count() == 1)
	assert(not sidebar.recipe_label(0).ends_with("*"))
	assert(panel.get_node("WorkArea/EditorArea/RecipeGraph") is ScatterGraphEditor)
	var graph_editor := panel.get_node("WorkArea/EditorArea/RecipeGraph") as ScatterGraphEditor
	assert(graph_editor.get_connection_list().size() == graph.connections.size())
	# GraphEdit emits disconnection_request while it is still processing the
	# mouse press. Rebuilding here would invalidate its port hot-zone lookup and
	# turn the connection gesture into an accidental box selection.
	var tested_connection := graph.connections[0]
	var tested_from_view := graph_editor.get_view(tested_connection.from_node_id)
	var tested_to_view := graph_editor.get_view(tested_connection.to_node_id)
	var tested_from_index := tested_from_view.output_port_index(tested_connection.from_port_id)
	var tested_to_index := tested_to_view.input_port_index(tested_connection.to_port_id, 0)
	var connection_count := graph.connections.size()
	graph_editor._disconnection_requested(
		tested_from_view.name,
		tested_from_index,
		tested_to_view.name,
		tested_to_index,
	)
	assert(graph.connections.size() == connection_count - 1)
	assert(is_instance_valid(tested_from_view) and tested_from_view.get_parent() == graph_editor)
	assert(graph_editor.get_connection_list().size() == connection_count)
	await process_frame
	assert(graph_editor.get_connection_list().size() == connection_count - 1)
	assert(graph_editor.get_view(tested_connection.from_node_id) == tested_from_view)
	assert(graph_editor.get_view(tested_connection.to_node_id) == tested_to_view)
	assert(graph_editor.controller.connect_ports(
		tested_connection.from_node_id,
		tested_connection.from_port_id,
		tested_connection.to_node_id,
		tested_connection.to_port_id,
		tested_connection.order,
	))
	await process_frame
	assert(graph_editor.get_connection_list().size() == connection_count)
	assert(graph_editor.get_view(tested_connection.from_node_id) == tested_from_view)
	assert(graph_editor.get_view(tested_connection.to_node_id) == tested_to_view)
	await _test_incremental_graph_updates(graph, graph_editor)
	var clipboard_graph := ScatterGraph.new()
	var clipboard_box := ScatterBoxNode.new()
	var clipboard_transform := ScatterShapeTransformNode.new()
	clipboard_graph.add_node(clipboard_box)
	clipboard_graph.add_node(clipboard_transform)
	assert(clipboard_box.get_output_ports()[0].label == "Regular Region")
	assert(clipboard_graph.connect_nodes(
		clipboard_box.node_id,
		&"region",
		clipboard_transform.node_id,
		&"geometry",
	) != null)
	assert(clipboard_transform.geometry_type == ScatterValueTypeRegistry.REGULAR_REGION)
	var adaptive_clipboard := ScatterGraphClipboard.new()
	adaptive_clipboard.capture(clipboard_graph, [clipboard_transform.node_id])
	var isolated_payload := adaptive_clipboard.instantiate(clipboard_graph, Vector2(200, 200))
	var isolated_transform := isolated_payload.nodes[0] as ScatterShapeTransformNode
	assert(isolated_transform.geometry_type == ScatterValueTypeRegistry.DYNAMIC_GEOMETRY)
	assert(isolated_transform.get_input_ports()[0].label == "Shape")
	adaptive_clipboard.capture(clipboard_graph, [clipboard_box.node_id, clipboard_transform.node_id])
	var connected_payload := adaptive_clipboard.instantiate(clipboard_graph, Vector2(400, 200))
	var connected_transform: ScatterShapeTransformNode
	for copied_node in connected_payload.nodes:
		if copied_node is ScatterShapeTransformNode:
			connected_transform = copied_node
			break
	assert(connected_transform != null)
	assert(connected_transform.geometry_type == ScatterValueTypeRegistry.REGULAR_REGION)
	assert(connected_transform.get_input_ports()[0].label == "Regular Region")
	var context := ScatterEditorContext.new()
	context.target = target
	context.graph = graph
	context.undo = ScatterUndoService.new()
	var view_count := 0
	for prototype in ScatterNodeRegistry.prototypes():
		var view_script := ScatterExtensionRegistry.get_view_script(prototype.get_type_id())
		var view = view_script.new()
		assert(view is ScatterNodeView)
		root.add_child(view)
		view.bind_model(prototype, context)
		assert(view.title == prototype.get_caption())
		if prototype is ScatterBoxNode or prototype is ScatterSphereNode:
			var port_label := view.get_child(1) as Label
			assert(port_label != null and port_label.text == "Regular Region")
		var top_padding := view.get_child(0) as Control
		var bottom_padding := view.get_child(view.get_child_count() - 1) as Control
		assert(top_padding.name == &"ContentPaddingTop")
		assert(bottom_padding.name == &"ContentPaddingBottom")
		assert(top_padding.custom_minimum_size.y > 0.0)
		assert(bottom_padding.custom_minimum_size.y == top_padding.custom_minimum_size.y)
		view_count += 1
		view.free()
	assert(view_count == 36)
	assert(InspectorScript != null)
	assert(GizmoScript != null)
	var gizmo = null
	var paint = PaintToolScript.new()
	paint.configure(panel, gizmo, null)
	paint.set_target(target)
	assert(paint.get_toolbar() != null)
	var path_tool = PathToolScript.new()
	path_tool.configure(gizmo, null, Callable())
	assert(path_tool.get_toolbar() != null)
	var path_node := ScatterPathNode.new()
	path_node.points = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT])
	graph.add_node(path_node, Vector2(100, 600))
	var paint_node := ScatterPaintRegionNode.new()
	paint_node.strokes = [ScatterPaintStroke.create(Vector3.ZERO, Vector3.UP, 1.0)]
	graph.add_node(paint_node, Vector2(400, 600))
	graph_editor.rebuild_graph()
	graph_editor.get_view(path_node.node_id).selected = true
	await process_frame
	assert(panel.active_viewport_tool == &"path")
	graph_editor.get_view(paint_node.node_id).selected = true
	await process_frame
	assert(panel.active_viewport_tool == &"paint")
	paint.activate()
	assert(paint.get_toolbar().visible)
	graph_editor.get_view(paint_node.node_id).selected = false
	await process_frame
	assert(panel.active_viewport_tool.is_empty())
	paint.stop()
	assert(not paint.get_toolbar().visible)
	graph.seed = 99173
	panel._on_recipe_changed()
	assert(sidebar.recipe_count() == 1)
	assert(sidebar.recipe_label(0).ends_with("*"))
	assert(panel.get_graph_for_build(target) == graph)
	assert(ScatterGraphAttachment.get_graph(target).seed != graph.seed)
	var reopened_target := MultiMeshInstance3D.new()
	assert(ScatterGraphAttachment.attach(reopened_target, ScatterGraphAttachment.get_graph(target)))
	panel.set_target(reopened_target)
	assert(panel.graph.seed != graph.seed)
	panel.set_target(target)
	assert(panel.graph == graph)
	reopened_target.free()
	var before_save := ResourceLoader.load(
		recipe_path,
		"ScatterGraph",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as ScatterGraph
	assert(before_save != null and before_save.seed != graph.seed)
	var save_shortcut := InputEventKey.new()
	save_shortcut.keycode = KEY_S
	save_shortcut.ctrl_pressed = true
	save_shortcut.pressed = true
	graph_editor.grab_focus()
	await process_frame
	assert(panel._has_editor_keyboard_focus())
	assert(panel._is_recipe_save_shortcut(save_shortcut))
	root.push_input(save_shortcut)
	await process_frame
	var loaded := ResourceLoader.load(
		recipe_path,
		"ScatterGraph",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as ScatterGraph
	assert(loaded != null)
	assert(loaded.seed == graph.seed)
	assert(ScatterGraphAttachment.get_graph(target).seed == graph.seed)
	assert(not sidebar.recipe_label(0).ends_with("*"))
	assert(loaded.nodes.size() == graph.nodes.size())
	assert(loaded.connections.size() == graph.connections.size())
	var loaded_paint := loaded.find_node(paint_node.node_id) as ScatterPaintRegionNode
	assert(loaded_paint != null and loaded_paint.strokes.size() == 1)
	await _test_scene_recipe_session_lifecycle(panel)
	path_tool.get_toolbar().free()
	paint.get_toolbar().free()
	path_tool = null
	paint = null
	links = null
	panel.queue_free()
	target.queue_free()
	await process_frame
	await process_frame
	ScatterBuiltinRegistry.unregister_all()
	print("Scatter editor architecture test passed")
	quit()


func _test_incremental_graph_updates(
		graph: ScatterGraph,
		graph_editor: ScatterGraphEditor,
) -> void:
	var initial_node_count := graph.nodes.size()
	var initial_connection_count := graph.connections.size()
	var stable_node := graph.find_first(&"random_rotation")
	var stable_view := graph_editor.get_view(stable_node.node_id)

	# Add and Delete patch only the changed node.
	var added := graph_editor.controller.add_node(&"set_color", Vector2(700, 500))
	assert(added != null and graph_editor.get_view(added.node_id) == null)
	await process_frame
	var added_view := graph_editor.get_view(added.node_id)
	assert(added_view != null)
	assert(graph_editor.get_view(stable_node.node_id) == stable_view)
	graph_editor.controller.delete_nodes([added.node_id])
	assert(graph_editor.get_view(added.node_id) == added_view)
	await process_frame
	assert(graph_editor.get_view(added.node_id) == null)
	assert(graph_editor.get_view(stable_node.node_id) == stable_view)
	assert(graph.nodes.size() == initial_node_count)

	# Paste adds a subgraph and its internal connections without touching views
	# that were already present.
	var scale_node := graph.find_first(&"scale")
	var paste_buffer := ScatterGraphClipboard.new()
	paste_buffer.capture(graph, [stable_node.node_id, scale_node.node_id])
	var pasted_ids := graph_editor.controller.paste(paste_buffer, Vector2(500, 700))
	assert(pasted_ids.size() == 2)
	for node_id in pasted_ids:
		assert(graph_editor.get_view(node_id) == null)
	await process_frame
	for node_id in pasted_ids:
		assert(graph_editor.get_view(node_id) != null)
	assert(graph_editor.get_view(stable_node.node_id) == stable_view)
	assert(graph.nodes.size() == initial_node_count + 2)
	assert(graph.connections.size() == initial_connection_count + 1)
	assert(graph_editor.get_connection_list().size() == graph.connections.size())
	graph_editor.controller.delete_nodes(pasted_ids)
	await process_frame
	assert(graph.nodes.size() == initial_node_count)
	assert(graph.connections.size() == initial_connection_count)
	assert(graph_editor.get_connection_list().size() == graph.connections.size())
	assert(graph_editor.get_view(stable_node.node_id) == stable_view)

	# Variadic Final Output rows depend on connection count, so only that view is
	# replaced while unrelated views keep their identity.
	var single := graph_editor.controller.add_node(&"single", Vector2(700, 700))
	await process_frame
	var final_node := graph.final_output_node()
	var final_before := graph_editor.get_view(final_node.node_id)
	var incoming_before := graph.incoming_connections(final_node.node_id, &"instances").size()
	assert(graph_editor.controller.connect_ports(single.node_id, &"instances", final_node.node_id, &"instances"))
	var single_connection: ScatterConnection
	for connection in graph.incoming_connections(final_node.node_id, &"instances"):
		if connection.from_node_id == single.node_id:
			single_connection = connection
			break
	assert(single_connection != null)
	assert(graph_editor.get_view(final_node.node_id) == final_before)
	await process_frame
	var final_connected := graph_editor.get_view(final_node.node_id)
	assert(final_connected != final_before)
	assert(final_connected.input_port_order.size() == incoming_before + 2)
	assert(graph_editor.get_connection_list().size() == graph.connections.size())
	assert(graph_editor.get_view(stable_node.node_id) == stable_view)
	graph_editor.controller.disconnect_connection(single_connection)
	await process_frame
	var final_disconnected := graph_editor.get_view(final_node.node_id)
	assert(final_disconnected != final_connected)
	assert(final_disconnected.input_port_order.size() == incoming_before + 1)
	assert(graph_editor.get_connection_list().size() == graph.connections.size())
	assert(graph_editor.get_view(stable_node.node_id) == stable_view)
	graph_editor.controller.delete_nodes([single.node_id])
	await process_frame

	# Shape Transform changes its adaptive port label and visual type when a
	# connection is made. Rebuild only that dynamic-port view.
	var shape_transform := graph_editor.controller.add_node(&"shape_transform", Vector2(350, 700)) as ScatterShapeTransformNode
	await process_frame
	var shape_before := graph_editor.get_view(shape_transform.node_id)
	var box_node := graph.find_first(&"shape_box")
	assert(graph_editor.controller.connect_ports(box_node.node_id, &"region", shape_transform.node_id, &"geometry"))
	var shape_connection := graph.incoming_connections(shape_transform.node_id, &"geometry")[0]
	await process_frame
	var shape_connected := graph_editor.get_view(shape_transform.node_id)
	assert(shape_connected != shape_before)
	assert(shape_transform.geometry_type == ScatterValueTypeRegistry.REGULAR_REGION)
	assert(_view_has_label(shape_connected, "Regular Region"))
	assert(graph_editor.get_connection_list().size() == graph.connections.size())
	assert(graph_editor.get_view(stable_node.node_id) == stable_view)
	graph_editor.controller.disconnect_connection(shape_connection)
	await process_frame
	var shape_disconnected := graph_editor.get_view(shape_transform.node_id)
	assert(shape_disconnected != shape_connected)
	assert(shape_transform.geometry_type == ScatterValueTypeRegistry.DYNAMIC_GEOMETRY)
	assert(_view_has_label(shape_disconnected, "Shape"))
	assert(graph_editor.get_connection_list().size() == graph.connections.size())
	assert(graph_editor.get_view(stable_node.node_id) == stable_view)
	graph_editor.controller.delete_nodes([shape_transform.node_id])
	await process_frame

	# EditorUndoRedoManager is owned by the editor and cannot be constructed by
	# a headless SceneTree test. Exercise the exact model methods and structural
	# callback registered on both sides of the real UndoRedo action.
	var undo_node := graph_editor.controller.add_node(&"set_color", Vector2(700, 500))
	await process_frame
	assert(graph_editor.get_view(undo_node.node_id) != null)
	assert(graph_editor.get_view(stable_node.node_id) == stable_view)
	graph.remove_nodes([undo_node.node_id])
	graph_editor.controller._notify_structure_changed()
	await process_frame
	assert(graph_editor.get_view(undo_node.node_id) == null)
	assert(graph_editor.get_view(stable_node.node_id) == stable_view)
	graph.add_existing_nodes([undo_node], [])
	graph_editor.controller._notify_structure_changed()
	await process_frame
	assert(graph_editor.get_view(undo_node.node_id) != null)
	assert(graph_editor.get_view(stable_node.node_id) == stable_view)
	graph.remove_nodes([undo_node.node_id])
	graph_editor.controller._notify_structure_changed()
	await process_frame
	assert(graph_editor.get_view(undo_node.node_id) == null)
	assert(graph.nodes.size() == initial_node_count)
	assert(graph.connections.size() == initial_connection_count)


func _view_has_label(view: ScatterNodeView, text: String) -> bool:
	for child in view.get_children():
		if child is Label and child.text == text:
			return true
	return false


func _test_scene_recipe_session_lifecycle(panel: ScatterPanel) -> void:
	var recipe_path := "user://scatter_scene_session_recipe.tres"
	var scene_path := "user://scatter_scene_session_test.tscn"
	var saved_graph := ScatterGraphFactory.create_default()
	saved_graph.seed = 101
	assert(ScatterRecipeIO.save_graph(saved_graph, recipe_path) == OK)
	var scene_root := Node3D.new()
	scene_root.name = "SessionScene"
	var scene_target := MultiMeshInstance3D.new()
	scene_target.name = "ScatterTarget"
	scene_root.add_child(scene_target)
	scene_target.owner = scene_root
	assert(ScatterGraphAttachment.attach(scene_target, saved_graph))
	var packed := PackedScene.new()
	assert(packed.pack(scene_root) == OK)
	assert(ResourceSaver.save(packed, scene_path) == OK)
	scene_root.free()

	var opened_scene := (ResourceLoader.load(
		scene_path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as PackedScene).instantiate()
	root.add_child(opened_scene)
	var opened_target := opened_scene.get_node("ScatterTarget") as MultiMeshInstance3D
	panel.set_target(opened_target)
	assert(panel.graph.seed == 101)
	panel.graph.seed = 202
	panel._on_recipe_changed()
	assert(panel.graph.seed == 202)
	assert(panel.close_scene_sessions(scene_path))
	opened_scene.free()

	var reopened_scene := (ResourceLoader.load(
		scene_path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as PackedScene).instantiate()
	root.add_child(reopened_scene)
	var reopened_target := reopened_scene.get_node("ScatterTarget") as MultiMeshInstance3D
	panel.set_target(reopened_target)
	assert(panel.graph.seed == 101)
	reopened_scene.free()
