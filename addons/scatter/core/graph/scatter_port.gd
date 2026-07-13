@tool
class_name ScatterPort
extends RefCounted

enum ValueType {
	REGION = 1,
	INSTANCES = 2,
	SCATTER_SET = 3,
}

const COLORS := {
	ValueType.REGION: Color("55b8a6"),
	ValueType.INSTANCES: Color("b889e8"),
	ValueType.SCATTER_SET: Color("e1a85a"),
}

var id: StringName
var label: String
var value_type: ValueType
var variadic := false


func _init(
		p_id: StringName = &"value",
		p_label := "Value",
		p_value_type: ValueType = ValueType.INSTANCES,
		p_variadic := false,
) -> void:
	id = p_id
	label = p_label
	value_type = p_value_type
	variadic = p_variadic


func color() -> Color:
	return COLORS.get(value_type, Color.WHITE)
