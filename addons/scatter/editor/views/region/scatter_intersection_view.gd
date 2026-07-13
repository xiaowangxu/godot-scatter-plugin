@tool
class_name ScatterIntersectionView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"a", &"", "A")
	add_port_row(&"b", &"", "B")
	add_port_row(&"", &"region", "Region")


func _build_properties() -> void:
	pass
