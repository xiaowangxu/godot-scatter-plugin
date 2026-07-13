@tool
class_name ScatterStatusBar
extends HBoxContainer

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_label)


func show_message(message: String) -> void:
	_label.text = message


func show_instance_count(count: int) -> void:
	_label.text = tr("%d instances - editor-generated MultiMesh buffer is ready for runtime.") % count
