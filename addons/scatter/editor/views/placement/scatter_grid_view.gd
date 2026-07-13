@tool
class_name ScatterGridView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"shape", &"", "Shape")
	add_port_row(&"", &"instances", "Instances")


func _build_properties() -> void:
	add_vector3_property(&"spacing", "Spacing")
