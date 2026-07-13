@tool
class_name ScatterPort
extends RefCounted

var id: StringName
var label: String
var type_id: StringName
var variadic := false
var connectable := true
var visible := true


func _init(
		p_id: StringName = &"value",
		p_label := "Value",
		p_type_id: StringName = ScatterValueTypeRegistry.INSTANCES,
		p_variadic := false,
		p_connectable := true,
		p_visible := true,
) -> void:
	id = p_id
	label = p_label
	type_id = p_type_id
	variadic = p_variadic
	connectable = p_connectable
	visible = p_visible


func color() -> Color:
	return ScatterValueTypeRegistry.color(type_id)


func visual_type() -> int:
	return ScatterValueTypeRegistry.visual_id(type_id)
