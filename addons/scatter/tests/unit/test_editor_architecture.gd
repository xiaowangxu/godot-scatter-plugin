@tool
extends SceneTree

const InspectorScript := preload("res://addons/scatter/editor/inspector/scatter_inspector_plugin.gd")
const GizmoScript := preload("res://addons/scatter/editor/gizmo/scatter_gizmo_plugin.gd")
const PaintToolScript := preload("res://addons/scatter/editor/paint/scatter_paint_tool.gd")


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
	var recipe_path := "user://scatter_oop_recipe_test.tres"
	assert(ScatterRecipeIO.save_graph(graph, recipe_path) == OK)
	var loaded := ScatterRecipeIO.load_graph(recipe_path)
	assert(loaded != null)
	assert(loaded.nodes.size() == graph.nodes.size())
	assert(loaded.connections.size() == graph.connections.size())
	panel.queue_free()
	target.free()
	ScatterBuiltinRegistry.unregister_all()
	print("Scatter editor architecture test passed")
	quit()
