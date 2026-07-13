@tool
class_name ScatterPathView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"", &"region", "Region")


func _build_properties() -> void:
	add_number_property(&"thickness", "Thickness", 0.0, 1000000.0, 0.1)
	add_bool_property(&"closed", "Closed")


func get_viewport_tool_id() -> StringName:
	return &"path"
