@tool
class_name ScatterRemoveOutsideView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"instances", &"instances", "Instances")


func _build_properties() -> void:
	add_bool_property(&"negative_shapes_only", "Negative Shapes Only")
