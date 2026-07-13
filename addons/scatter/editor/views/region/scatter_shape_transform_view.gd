@tool
class_name ScatterShapeTransformView
extends ScatterNodeView


func _build_ports() -> void:
	add_port_row(&"shape", &"shape", "Shape")
	add_port_row(&"path", &"path", "Path")


func _build_properties() -> void:
	add_vector3_property(&"position", "Position")
	add_vector3_property(&"rotation", "Rotation")
	add_vector3_property(&"scale", "Scale")
