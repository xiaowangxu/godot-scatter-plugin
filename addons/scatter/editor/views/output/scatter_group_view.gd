@tool
class_name ScatterGroupView
extends ScatterNodeView

var _count_label: Label


func minimum_width() -> float:
	return 225.0


func _build_ports() -> void:
	add_port_row(&"", &"set", "Scatter Set")
	add_port_row(&"region", &"", "Region")
	add_port_row(&"placement", &"", "Placement")
	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.modulate = Color("d8b36f")
	add_child(_count_label)
	update_runtime_stats()


func _build_properties() -> void:
	pass


func update_runtime_stats() -> void:
	if _count_label != null and context != null:
		_count_label.text = tr("%d instances") % context.group_counts.get(model.node_id, 0)
