@tool
class_name ScatterBuiltinNodeView
extends ScatterNodeView

const HIDDEN_PROPERTIES: Array[StringName] = [
	&"node_id",
	&"graph_position",
	&"enabled",
	&"override_seed",
	&"custom_seed",
	&"points",
	&"strokes",
]

const LABEL_OVERRIDES := {
	&"instance_count": "Instance Count",
	&"max_points": "Maximum Points",
	&"min_amount": "Minimum Amount",
	&"samples_before_rejection": "Rejection Samples",
	&"consecutive_step_multiplier": "Step Multiplier",
	&"remove_points_on_miss": "Remove on Miss",
	&"align_with_collision_normal": "Align to Normal",
	&"max_slope": "Maximum Slope",
	&"individual_rotation_pivots": "Individual Pivots",
}

const TOOLTIP_OVERRIDES := {
	"create_grid:space": "Global uses world axes, Local uses MultiMesh axes, and Instance uses the Shape local transform.",
	"create_grid:offset": "Grid phase offset in the selected Space.",
	"region_union:pivot": "Defines the result's local reference frame without changing its geometry.",
	"region_intersection:pivot": "Defines the result's local reference frame without changing its geometry.",
	"region_subtract:pivot": "Defines the result's local reference frame without changing its geometry.",
}


func _build_ports() -> void:
	var paired: Dictionary[StringName, bool] = {}
	for output in model.get_output_ports():
		if not output.visible:
			continue
		var input := model.input_port(output.id)
		if input != null and input.visible:
			add_port_row(input.id, output.id, output.label)
			paired[output.id] = true
		else:
			add_port_row(&"", output.id, output.label)
	for input in model.get_input_ports():
		if input.visible and not paired.has(input.id):
			add_port_row(input.id, &"", input.label)


func _build_properties() -> void:
	for property_info in model.get_property_list():
		if not _is_editable_property(property_info):
			continue
		_add_exported_property(property_info)


func get_viewport_tool_id() -> StringName:
	return &"path" if model != null and model.get_type_id() == &"shape_path" else &""


func _is_editable_property(info: Dictionary) -> bool:
	var property: StringName = info.name
	var usage := int(info.usage)
	return (
		not HIDDEN_PROPERTIES.has(property)
		and (usage & PROPERTY_USAGE_EDITOR) != 0
		and (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0
		and int(info.type) in [
			TYPE_BOOL,
			TYPE_INT,
			TYPE_FLOAT,
			TYPE_STRING,
			TYPE_VECTOR2,
			TYPE_VECTOR3,
			TYPE_COLOR,
			TYPE_NODE_PATH,
		]
	)


func _add_exported_property(info: Dictionary) -> void:
	var property: StringName = info.name
	var label := String(LABEL_OVERRIDES.get(property, String(property).capitalize()))
	var type := int(info.type)
	var hint := int(info.hint)
	var hint_string := String(info.hint_string)
	var tooltip := String(TOOLTIP_OVERRIDES.get("%s:%s" % [model.get_type_id(), property], ""))
	match type:
		TYPE_BOOL:
			add_bool_property(property, label, tooltip)
		TYPE_INT, TYPE_FLOAT:
			if hint == PROPERTY_HINT_ENUM:
				add_enum_property(property, label, _enum_labels(hint_string), tooltip)
			else:
				var range_values := _number_range(type, hint, hint_string)
				add_number_property(
					property,
					label,
					range_values.x,
					range_values.y,
					range_values.z,
					type == TYPE_INT,
					tooltip,
				)
		TYPE_STRING:
			if hint in [PROPERTY_HINT_FILE, PROPERTY_HINT_GLOBAL_FILE, PROPERTY_HINT_SAVE_FILE, PROPERTY_HINT_GLOBAL_SAVE_FILE]:
				add_file_property(property, label, tooltip)
			else:
				add_file_property(property, label, tooltip)
		TYPE_VECTOR2:
			add_vector2_property(property, label, tooltip)
		TYPE_VECTOR3:
			add_vector3_property(property, label, tooltip)
		TYPE_COLOR:
			add_color_property(property, label, tooltip)
		TYPE_NODE_PATH:
			add_node_path_property(property, label, tooltip)


func _number_range(type: int, hint: int, hint_string: String) -> Vector3:
	if hint == PROPERTY_HINT_RANGE:
		var parts := hint_string.split(",")
		if parts.size() >= 2:
			return Vector3(
				parts[0].to_float(),
				parts[1].to_float(),
				parts[2].to_float() if parts.size() >= 3 else (1.0 if type == TYPE_INT else 0.01),
			)
	if hint == PROPERTY_HINT_LAYERS_3D_PHYSICS:
		return Vector3(0.0, 4294967295.0, 1.0)
	return Vector3(-1000000.0, 1000000.0, 1.0 if type == TYPE_INT else 0.05)


func _enum_labels(hint_string: String) -> PackedStringArray:
	var result := PackedStringArray()
	for raw_label in hint_string.split(","):
		result.append(raw_label.get_slice(":", 0).strip_edges())
	return result
