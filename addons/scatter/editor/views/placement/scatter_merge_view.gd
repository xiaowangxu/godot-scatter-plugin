@tool
class_name ScatterMergeView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"a", &"", "A")
	add_port_row(&"b", &"", "B")
	add_port_row(&"", &"instances", "Instances")


func _build_properties() -> void:
	pass
