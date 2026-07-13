@tool
class_name ScatterUnionView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"region", "Region")
	add_port_row(&"a", &"", "A")
	add_port_row(&"b", &"", "B")


func _build_properties() -> void:
	pass
