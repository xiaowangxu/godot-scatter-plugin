@tool
extends SceneTree

const InspectorScript := preload("res://addons/scatter/editor/inspector/scatter_inspector_plugin.gd")
const GizmoScript := preload("res://addons/scatter/editor/gizmo/scatter_gizmo_plugin.gd")
const PaintToolScript := preload("res://addons/scatter/editor/paint/scatter_paint_tool.gd")
const PathToolScript := preload("res://addons/scatter/editor/paint/scatter_path_tool.gd")


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
	var target := MultiMeshInstance3D.new()
	var recipe_path := "user://scatter_oop_recipe_test.tres"
	assert(ScatterRecipeIO.save_graph(graph, recipe_path) == OK)
	assert(ScatterGraphAttachment.attach(target, graph))
	var counter := CallbackCounter.new()
	var controller := ScatterGraphController.new()
	controller.configure(
		graph,
		target,
		null,
		Callable(),
		Callable(),
		counter.graph_changed,
		counter.build_requested,
	)
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
	assert(panel.get_node("RecipeGraph") is ScatterGraphEditor)
	var context := ScatterEditorContext.new()
	context.target = target
	context.graph = graph
	context.undo = ScatterUndoService.new()
	var view_count := 0
	for prototype in ScatterNodeRegistry.prototypes():
		var view_script := ScatterNodeRegistry.get_view_script(prototype.get_type_id())
		var view = view_script.new()
		assert(view is ScatterNodeView)
		root.add_child(view)
		view.bind_model(prototype, context)
		assert(view.title == prototype.get_caption())
		view_count += 1
		view.free()
	assert(view_count == 34)
	assert(InspectorScript != null)
	assert(GizmoScript != null)
	var gizmo = null
	var paint = PaintToolScript.new()
	paint.configure(panel, gizmo, null, Callable(), Callable())
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
	var graph_editor := panel.get_node("RecipeGraph") as ScatterGraphEditor
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
	assert(loaded.nodes.size() == graph.nodes.size())
	assert(loaded.connections.size() == graph.connections.size())
	var loaded_paint := loaded.find_node(paint_node.node_id) as ScatterPaintRegionNode
	assert(loaded_paint != null and loaded_paint.strokes.size() == 1)
	path_tool.get_toolbar().free()
	paint.get_toolbar().free()
	panel.queue_free()
	target.free()
	ScatterBuiltinRegistry.unregister_all()
	print("Scatter editor architecture test passed")
	quit()
