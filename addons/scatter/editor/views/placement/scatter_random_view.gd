@tool
class_name ScatterRandomView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"instances", "Instances")


func _build_properties() -> void:
	add_number_property(&"amount", "Amount", 0, 1000000, 1, true)
	add_bool_property(&"restrict_height", "Restrict Height")
