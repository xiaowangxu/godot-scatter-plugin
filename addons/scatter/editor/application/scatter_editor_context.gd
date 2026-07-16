@tool
class_name ScatterEditorContext
extends RefCounted

enum ChangeKind {
	PROPERTY,
	STRUCTURE,
	LAYOUT,
}

var target: MultiMeshInstance3D
var graph: ScatterGraph
var undo: ScatterUndoService
var sync_views: Callable
var reconcile_structure: Callable
var graph_changed: Callable
var build_requested: Callable
var output_counts: Dictionary = {}


func commit_property(
		object: Object,
		property: StringName,
		value: Variant,
		caption: String,
		component := "",
		merge_mode := UndoRedo.MERGE_DISABLE,
) -> void:
	if undo != null:
		undo.commit_property(object, property, value, caption, component, merge_mode)


func notify_model_changed(kind := ChangeKind.PROPERTY) -> void:
	if graph != null:
		graph.emit_changed()
	if kind == ChangeKind.STRUCTURE and reconcile_structure.is_valid():
		reconcile_structure.call()
	elif sync_views.is_valid():
		sync_views.call()
	if graph_changed.is_valid():
		graph_changed.call()
	if kind != ChangeKind.LAYOUT and graph != null and graph.auto_rebuild and build_requested.is_valid():
		build_requested.call()
