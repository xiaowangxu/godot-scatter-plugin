@tool
class_name ScatterPathView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"region", "Region")


func _build_properties() -> void:
	add_path_property(&"points", "Points", "Use x,y,z; x,y,z format")
	add_number_property(&"thickness", "Thickness", 0.0, 1000000.0, 0.1)
	add_bool_property(&"closed", "Closed")
