extends SceneTree


func _init() -> void:
	ScatterBuiltinRegistry.register_all()
	var core_files := _gd_files("res://addons/scatter/core")
	var editor_files := _gd_files("res://addons/scatter/editor")
	assert(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/scatter/core/services")))
	assert(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/scatter/editor/views")))
	assert(_gd_files("res://addons/scatter/editor/graph/views").size() == 4)
	for path in core_files:
		var source := FileAccess.get_file_as_string(path)
		assert(not source.contains("EditorPlugin"), "Core cannot depend on EditorPlugin: %s" % path)
		assert(not source.contains("EditorUndoRedo"), "Core cannot depend on editor UndoRedo: %s" % path)
		assert(not source.contains("GraphNode"), "Core cannot depend on GraphNode: %s" % path)
		assert(not source.contains("extends Control"), "Core cannot extend Control: %s" % path)
	var evaluator := FileAccess.get_file_as_string("res://addons/scatter/core/execution/scatter_graph_evaluator.gd")
	assert(not evaluator.contains("get_type_id"))
	assert(not evaluator.contains("match node"))
	var han := RegEx.new()
	assert(han.compile("[\\x{4E00}-\\x{9FFF}]") == OK)
	for path in editor_files:
		assert(han.search(FileAccess.get_file_as_string(path)) == null, "Editor UI source must use English tr() text: %s" % path)
	assert(ScatterNodeRegistry.type_ids().size() == 36)
	assert(not evaluator.contains("ScatterBoxNode"))
	var gizmo := FileAccess.get_file_as_string("res://addons/scatter/editor/gizmo/scatter_gizmo_plugin.gd")
	assert(not gizmo.contains("ScatterPathNode"))
	assert(not gizmo.contains("ScatterPaintRegionNode"))
	print("Scatter architecture rule test passed")
	quit()


func _gd_files(path: String) -> PackedStringArray:
	return _matching_files(path, ".gd")


func _matching_files(path: String, suffix: String) -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open(path)
	assert(directory != null)
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		var child := path.path_join(entry)
		if directory.current_is_dir():
			result.append_array(_matching_files(child, suffix))
		elif entry.ends_with(suffix):
			result.append(child)
		entry = directory.get_next()
	directory.list_dir_end()
	return result
