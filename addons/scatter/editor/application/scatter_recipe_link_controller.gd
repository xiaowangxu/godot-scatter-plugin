@tool
class_name ScatterRecipeLinkController
extends RefCounted

signal changed(target: MultiMeshInstance3D)

var undo_redo: EditorUndoRedoManager


func _init(p_undo_redo: EditorUndoRedoManager = null) -> void:
	undo_redo = p_undo_redo


func link(
		target: MultiMeshInstance3D,
		graph: ScatterGraph,
		caption := "Link Scatter Recipe",
) -> void:
	if not is_instance_valid(target) or graph == null:
		return
	_apply_with_undo(target, graph, caption)


func detach(target: MultiMeshInstance3D, caption := "Detach Scatter Recipe") -> void:
	if is_instance_valid(target) and ScatterGraphAttachment.get_graph(target) != null:
		_apply_with_undo(target, null, caption)


func _apply_with_undo(target: MultiMeshInstance3D, graph: ScatterGraph, caption: String) -> void:
	var previous := ScatterGraphAttachment.get_graph(target)
	if previous == graph:
		return
	if undo_redo == null:
		_apply(target, graph)
		return
	undo_redo.create_action(caption, UndoRedo.MERGE_DISABLE, target)
	undo_redo.add_do_method(self, "_apply", target, graph)
	undo_redo.add_undo_method(self, "_apply", target, previous)
	undo_redo.commit_action()


func _apply(target: MultiMeshInstance3D, graph: ScatterGraph) -> void:
	if not is_instance_valid(target):
		return
	if graph == null:
		ScatterGraphAttachment.detach(target)
	elif not ScatterGraphAttachment.attach(target, graph):
		return
	target.notify_property_list_changed()
	changed.emit(target)
