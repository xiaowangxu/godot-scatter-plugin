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
	for entry in _property_layout_entries():
		match entry.kind:
			&"category":
				add_property_category(entry.label)
			&"group":
				add_property_group(entry.label)
			&"subgroup":
				add_property_subgroup(entry.label)
			&"property":
				_add_exported_property(entry.info, entry.display_name)


func get_viewport_tool_id() -> StringName:
	return &"path" if model != null and model.get_type_id() == &"shape_path" else &""


func _is_editable_property(info: Dictionary) -> bool:
	var property: StringName = info.name
	var usage := int(info.usage)
	return (
		not HIDDEN_PROPERTIES.has(property)
		and (usage & PROPERTY_USAGE_EDITOR) != 0
		and (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0
		and (usage & PROPERTY_USAGE_INTERNAL) == 0
		and int(info.type) in [
			TYPE_BOOL,
			TYPE_INT,
			TYPE_FLOAT,
			TYPE_STRING,
			TYPE_STRING_NAME,
			TYPE_VECTOR2,
			TYPE_VECTOR3,
			TYPE_COLOR,
			TYPE_NODE_PATH,
		]
)


func _add_exported_property(info: Dictionary, display_name: String) -> void:
	var property: StringName = info.name
	var label := String(LABEL_OVERRIDES.get(property, display_name.capitalize()))
	var type := int(info.type)
	var hint := int(info.hint)
	var hint_string := String(info.hint_string)
	var usage := int(info.usage)
	var tooltip := String(TOOLTIP_OVERRIDES.get("%s:%s" % [model.get_type_id(), property], ""))
	var control: Control
	match type:
		TYPE_BOOL:
			control = add_bool_property(property, label, tooltip)
		TYPE_INT, TYPE_FLOAT:
			if _is_bitmask_hint(hint, usage):
				control = add_bitmask_property(property, label, _bitmask_items(hint, hint_string), tooltip)
			elif hint == PROPERTY_HINT_ENUM:
				var enum_spec := _enum_spec(hint_string, type)
				control = add_enum_property(property, label, enum_spec.labels, tooltip, enum_spec.values)
			else:
				var options := _number_options(type, hint, hint_string)
				control = add_number_property(
					property,
					label,
					options.minimum,
					options.maximum,
					options.step,
					type == TYPE_INT,
					tooltip,
					options,
				)
		TYPE_STRING, TYPE_STRING_NAME:
			if hint == PROPERTY_HINT_ENUM:
				var enum_spec := _enum_spec(hint_string, type)
				control = add_enum_property(property, label, enum_spec.labels, tooltip, enum_spec.values)
			elif hint == PROPERTY_HINT_ENUM_SUGGESTION:
				control = add_suggestion_property(property, label, _choice_labels(hint_string), tooltip)
			elif hint == PROPERTY_HINT_MULTILINE_TEXT:
				control = add_multiline_property(property, label, tooltip)
			elif _is_path_hint(hint):
				control = add_file_property(property, label, tooltip, _file_options(hint, hint_string))
			else:
				control = add_text_property(property, label, tooltip, {
					"placeholder": hint_string if hint == PROPERTY_HINT_PLACEHOLDER_TEXT else "",
					"secret": hint == PROPERTY_HINT_PASSWORD,
				})
		TYPE_VECTOR2:
			control = add_vector2_property(property, label, tooltip, _display_options(hint_string))
		TYPE_VECTOR3:
			control = add_vector3_property(property, label, tooltip, _display_options(hint_string))
		TYPE_COLOR:
			control = add_color_property(property, label, tooltip, hint == PROPERTY_HINT_COLOR_NO_ALPHA)
		TYPE_NODE_PATH:
			control = add_node_path_property(property, label, tooltip)
	if control != null and (usage & PROPERTY_USAGE_READ_ONLY) != 0:
		var edit_root := control.get_parent() as Control
		set_property_control_editable(edit_root if edit_root != null else control, false)


func _property_layout_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var automatic_categories := _automatic_category_names()
	var category: Dictionary = {}
	var group: Dictionary = {}
	var subgroup: Dictionary = {}
	var serial := 0
	var previous_category_id := -1
	var previous_group_id := -1
	var previous_subgroup_id := -1
	for info in model.get_property_list():
		var usage := int(info.usage)
		var marker_name := String(info.name)
		if (usage & PROPERTY_USAGE_CATEGORY) != 0:
			serial += 1
			category = {
				"id": serial,
				"label": marker_name,
				"visible": not marker_name.is_empty() and not automatic_categories.has(marker_name),
			}
			group = {}
			subgroup = {}
			continue
		if (usage & PROPERTY_USAGE_GROUP) != 0:
			serial += 1
			group = {} if marker_name.is_empty() else {
				"id": serial,
				"label": marker_name,
				"prefix": String(info.hint_string),
			}
			subgroup = {}
			continue
		if (usage & PROPERTY_USAGE_SUBGROUP) != 0:
			serial += 1
			subgroup = {} if marker_name.is_empty() else {
				"id": serial,
				"label": marker_name,
				"prefix": String(info.hint_string),
			}
			continue
		if not _is_editable_property(info):
			continue
		var property_name := String(info.name)
		var group_applies := _section_applies(group, property_name)
		var subgroup_applies := group_applies and _section_applies(subgroup, property_name)
		var category_id := int(category.get("id", -1))
		var group_id := int(group.get("id", -1)) if group_applies else -1
		var subgroup_id := int(subgroup.get("id", -1)) if subgroup_applies else -1
		if category_id != previous_category_id:
			if category.get("visible", false):
				result.append({"kind": &"category", "label": category.label})
			previous_category_id = category_id
			previous_group_id = -1
			previous_subgroup_id = -1
		if group_id != previous_group_id:
			if group_applies:
				result.append({"kind": &"group", "label": group.label})
			previous_group_id = group_id
			previous_subgroup_id = -1
		if subgroup_id != previous_subgroup_id:
			if subgroup_applies:
				result.append({"kind": &"subgroup", "label": subgroup.label})
			previous_subgroup_id = subgroup_id
		var display_name := property_name
		if subgroup_applies:
			display_name = _trim_property_prefix(display_name, String(subgroup.get("prefix", "")))
		elif group_applies:
			display_name = _trim_property_prefix(display_name, String(group.get("prefix", "")))
		result.append({
			"kind": &"property",
			"info": info,
			"display_name": display_name,
		})
	return result


func _automatic_category_names() -> Dictionary:
	var result := {}
	var script := model.get_script() as Script
	while script != null:
		var filename := script.resource_path.get_file()
		if not filename.is_empty():
			result[filename] = true
			result[filename.get_basename()] = true
		if script.has_method("get_global_name"):
			var global_name := String(script.call("get_global_name"))
			if not global_name.is_empty():
				result[global_name] = true
		script = script.get_base_script()
	return result


func _section_applies(section: Dictionary, property_name: String) -> bool:
	if section.is_empty():
		return false
	var prefix := String(section.get("prefix", ""))
	return prefix.is_empty() or property_name.begins_with(prefix)


func _trim_property_prefix(property_name: String, prefix: String) -> String:
	return property_name.trim_prefix(prefix) if not prefix.is_empty() else property_name


func _number_options(type: int, hint: int, hint_string: String) -> Dictionary:
	var result := {
		"minimum": -1000000.0,
		"maximum": 1000000.0,
		"step": 1.0 if type == TYPE_INT else 0.05,
	}
	var parts := hint_string.split(",")
	if hint == PROPERTY_HINT_RANGE:
		if parts.size() >= 2:
			result.minimum = parts[0].to_float()
			result.maximum = parts[1].to_float()
			result.step = parts[2].to_float() if parts.size() >= 3 else (1.0 if type == TYPE_INT else 0.01)
	result.merge(_display_options(hint_string), true)
	for raw_part in parts:
		var part := raw_part.strip_edges()
		match part:
			"or_less", "or_lesser":
				result.allow_lesser = true
			"or_greater":
				result.allow_greater = true
			"exp":
				result.exp_edit = true
	return result


func _display_options(hint_string: String) -> Dictionary:
	var result := {}
	for raw_part in hint_string.split(","):
		var part := raw_part.strip_edges()
		if part.begins_with("suffix:"):
			result.suffix = part.trim_prefix("suffix:")
		elif part == "degrees":
			result.suffix = "°"
		elif part == "radians_as_degrees":
			result.display_scale = 180.0 / PI
			result.suffix = "°"
	return result


func _enum_spec(hint_string: String, type: int) -> Dictionary:
	var labels := PackedStringArray()
	var values: Array = []
	var next_value := 0
	for raw_item in hint_string.split(","):
		var item := raw_item.strip_edges()
		var label := item.get_slice(":", 0).strip_edges()
		labels.append(label)
		if type == TYPE_INT:
			var value := item.get_slice(":", 1).to_int() if item.contains(":") else next_value
			values.append(value)
			next_value = value + 1
		elif type == TYPE_STRING_NAME:
			values.append(StringName(label))
		else:
			values.append(label)
	return {"labels": labels, "values": values}


func _choice_labels(hint_string: String) -> PackedStringArray:
	var result := PackedStringArray()
	for raw_item in hint_string.split(","):
		result.append(raw_item.get_slice(":", 0).strip_edges())
	return result


func _is_bitmask_hint(hint: int, usage: int) -> bool:
	return hint in [
		PROPERTY_HINT_FLAGS,
		PROPERTY_HINT_LAYERS_2D_RENDER,
		PROPERTY_HINT_LAYERS_2D_PHYSICS,
		PROPERTY_HINT_LAYERS_2D_NAVIGATION,
		PROPERTY_HINT_LAYERS_3D_RENDER,
		PROPERTY_HINT_LAYERS_3D_PHYSICS,
		PROPERTY_HINT_LAYERS_3D_NAVIGATION,
		PROPERTY_HINT_LAYERS_AVOIDANCE,
	] or (usage & PROPERTY_USAGE_CLASS_IS_BITFIELD) != 0


func _bitmask_items(hint: int, hint_string: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if hint == PROPERTY_HINT_FLAGS or not hint_string.is_empty():
		var raw_items := hint_string.split(",")
		for index in raw_items.size():
			var item := raw_items[index].strip_edges()
			result.append({
				"label": item.get_slice(":", 0).strip_edges(),
				"value": item.get_slice(":", 1).to_int() if item.contains(":") else 1 << index,
			})
		return result
	var setting_prefix := _layer_setting_prefix(hint)
	for index in 32:
		var layer_name := String(ProjectSettings.get_setting(
			"%s/layer_%d" % [setting_prefix, index + 1],
			"",
		))
		result.append({
			"label": layer_name if not layer_name.is_empty() else "Layer %d" % (index + 1),
			"value": 1 << index,
		})
	return result


func _layer_setting_prefix(hint: int) -> String:
	match hint:
		PROPERTY_HINT_LAYERS_2D_RENDER:
			return "layer_names/2d_render"
		PROPERTY_HINT_LAYERS_2D_PHYSICS:
			return "layer_names/2d_physics"
		PROPERTY_HINT_LAYERS_2D_NAVIGATION:
			return "layer_names/2d_navigation"
		PROPERTY_HINT_LAYERS_3D_RENDER:
			return "layer_names/3d_render"
		PROPERTY_HINT_LAYERS_3D_PHYSICS:
			return "layer_names/3d_physics"
		PROPERTY_HINT_LAYERS_3D_NAVIGATION:
			return "layer_names/3d_navigation"
		_:
			return "layer_names/avoidance"


func _is_path_hint(hint: int) -> bool:
	return hint in [
		PROPERTY_HINT_FILE,
		PROPERTY_HINT_FILE_PATH,
		PROPERTY_HINT_GLOBAL_FILE,
		PROPERTY_HINT_SAVE_FILE,
		PROPERTY_HINT_GLOBAL_SAVE_FILE,
		PROPERTY_HINT_DIR,
		PROPERTY_HINT_GLOBAL_DIR,
	]


func _file_options(hint: int, hint_string: String) -> Dictionary:
	var global_access := hint in [
		PROPERTY_HINT_GLOBAL_FILE,
		PROPERTY_HINT_GLOBAL_SAVE_FILE,
		PROPERTY_HINT_GLOBAL_DIR,
	]
	var mode := FileDialog.FILE_MODE_OPEN_FILE
	if hint in [PROPERTY_HINT_SAVE_FILE, PROPERTY_HINT_GLOBAL_SAVE_FILE]:
		mode = FileDialog.FILE_MODE_SAVE_FILE
	elif hint in [PROPERTY_HINT_DIR, PROPERTY_HINT_GLOBAL_DIR]:
		mode = FileDialog.FILE_MODE_OPEN_DIR
	var filters := PackedStringArray()
	if not hint_string.is_empty() and mode != FileDialog.FILE_MODE_OPEN_DIR:
		for raw_filter in hint_string.split(","):
			filters.append(raw_filter.strip_edges())
	return {
		"access": FileDialog.ACCESS_FILESYSTEM if global_access else FileDialog.ACCESS_RESOURCES,
		"file_mode": mode,
		"filters": filters,
	}
