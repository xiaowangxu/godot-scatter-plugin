@tool
extends SceneTree

const InspectorScript := preload("res://addons/scatter/editor/inspector/scatter_inspector_plugin.gd")
const GizmoScript := preload("res://addons/scatter/editor/gizmo/scatter_gizmo_plugin.gd")
const PaintToolScript := preload("res://addons/scatter/editor/paint/scatter_paint_tool.gd")
const PathToolScript := preload("res://addons/scatter/editor/paint/scatter_path_tool.gd")


func _init() -> void:
	ScatterBuiltinRegistry.register_all()
	var graph := ScatterGraphFactory.create_default()
	var target := MultiMeshInstance3D.new()
	ScatterGraphAttachment.attach(target, graph)
	var panel := ScatterPanel.new()
	root.add_child(panel)
	panel.set_target(target)
	await process_frame
	assert(panel.graph == graph)
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
	var recipe_path := "user://scatter_oop_recipe_test.tres"
	assert(ScatterRecipeIO.save_graph(graph, recipe_path) == OK)
	var loaded := ScatterRecipeIO.load_graph(recipe_path)
	assert(loaded != null)
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
