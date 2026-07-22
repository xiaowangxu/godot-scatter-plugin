@tool
@abstract
class_name ScatterNodeView
extends GraphNode

const CONTENT_PADDING := 5.0

var model: ScatterNode
var context: ScatterEditorContext
var input_port_order: Array[StringName] = []
var output_port_order: Array[StringName] = []
var _bindings: Array[Dictionary] = []
var _syncing := false


func _enter_tree() -> void:
	set("theme_override_constants/separation", 8)


func bind_model(p_model: ScatterNode, p_context: ScatterEditorContext) -> void:
	model = p_model
	context = p_context
	name = str(model.node_id)
	title = tr(model.get_caption())
	tooltip_text = tr(model.get_description())
	position_offset = model.graph_position
	custom_minimum_size.x = minimum_width()
	if model.can_disable():
		var enabled := CheckBox.new()
		enabled.tooltip_text = tr("Enable or disable this node")
		enabled.button_pressed = model.enabled
		enabled.toggled.connect(_enabled_changed)
		get_titlebar_hbox().add_child(enabled)
		_bindings.append({"property": &"enabled", "kind": "bool", "control": enabled})
	_add_content_padding(&"ContentPaddingTop")
	_build_ports()
	if model.supports_seed():
		_add_seed_controls()
	_build_properties()
	_add_content_padding(&"ContentPaddingBottom")
	_tint_native_titlebar(model.get_color())


@abstract func _build_ports() -> void


@abstract func _build_properties() -> void


func minimum_width() -> float:
	return 270.0


func sync_from_model() -> void:
	if model == null:
		return
	_syncing = true
	position_offset = model.graph_position
	for binding in _bindings:
		var property: StringName = binding.property
		var value = model.get(property)
		match binding.kind:
			"bool":
				(binding.control as BaseButton).button_pressed = bool(value)
			"number":
				(binding.control as SpinBox).value = _number_to_display(float(value), binding.get("options", {}))
			"vector2", "vector3":
				var controls: Array = binding.controls
				var options: Dictionary = binding.get("options", {})
				for axis in controls.size():
					(controls[axis] as SpinBox).value = _number_to_display(value[axis], options)
			"enum":
				var values: Array = binding.get("values", [])
				(binding.control as OptionButton).select(values.find(value) if not values.is_empty() else int(value))
			"bitmask":
				_sync_bitmask_control(binding.control, int(value), binding.items)
			"color":
				var color: Color = value
				if binding.get("force_opaque", false):
					color.a = 1.0
				(binding.control as ColorPickerButton).color = color
			"path":
				(binding.control as LineEdit).text = _path_to_text(value)
			"text", "node_path":
				(binding.control as LineEdit).text = String(value)
			"multiline":
				(binding.control as TextEdit).text = String(value)
	_syncing = false
	update_runtime_stats()


func update_runtime_stats() -> void:
	pass


func structure_signature() -> Array:
	var result: Array = [model.get_type_id() if model != null else &""]
	if model == null:
		return result
	for port in model.get_input_ports():
		result.append(_port_signature(port, false))
	result.append(&"outputs")
	for port in model.get_output_ports():
		result.append(_port_signature(port, true))
	return result


func get_viewport_tool_id() -> StringName:
	return &""


func viewport_tool_activated() -> void:
	pass


func viewport_tool_deactivated() -> void:
	pass


func input_port_id(index: int) -> StringName:
	return input_port_order[index] if index >= 0 and index < input_port_order.size() else &""


func output_port_id(index: int) -> StringName:
	return output_port_order[index] if index >= 0 and index < output_port_order.size() else &""


func input_port_index(port_id: StringName, order := 0) -> int:
	var seen := 0
	for index in input_port_order.size():
		if input_port_order[index] != port_id:
			continue
		if seen == order:
			return index
		seen += 1
	return -1


func output_port_index(port_id: StringName) -> int:
	return output_port_order.find(port_id)


func add_port_row(
		input_id: StringName,
		output_id: StringName,
		label_text: String,
	) -> Label:
	var label := Label.new()
	label.text = tr(label_text)
	if not output_id.is_empty():
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(label)
	var input_port := model.input_port(input_id) if not input_id.is_empty() else null
	var output_port := model.output_port(output_id) if not output_id.is_empty() else null
	set_slot(
		get_child_count() - 1,
		input_port != null,
		input_port.visual_type() if input_port != null else 0,
		input_port.color() if input_port != null else Color.WHITE,
		output_port != null,
		output_port.visual_type() if output_port != null else 0,
		output_port.color() if output_port != null else Color.WHITE,
	)
	if input_port != null:
		input_port_order.append(input_id)
	if output_port != null:
		output_port_order.append(output_id)
	return label


func _add_content_padding(control_name: StringName) -> void:
	var spacer := Control.new()
	spacer.name = control_name
	spacer.custom_minimum_size.y = CONTENT_PADDING * maxf(get_theme_default_base_scale(), 1.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spacer)


func add_bool_property(property: StringName, label_text: String, tooltip := "") -> CheckBox:
	var control := CheckBox.new()
	control.button_pressed = bool(model.get(property))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.toggled.connect(_bool_changed.bind(property, label_text))
	_add_property_row(label_text, tooltip, control)
	_bindings.append({"property": property, "kind": "bool", "control": control})
	_tag_property_control(control, property, &"bool")
	return control


func add_number_property(
		property: StringName,
		label_text: String,
		minimum: float,
		maximum: float,
		step: float,
		integer := false,
		tooltip := "",
		options: Dictionary = {},
	) -> SpinBox:
	var control := SpinBox.new()
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.allow_lesser = options.get("allow_lesser", false)
	control.allow_greater = options.get("allow_greater", false)
	control.exp_edit = options.get("exp_edit", false)
	control.suffix = options.get("suffix", "")
	control.value = _number_to_display(float(model.get(property)), options)
	control.value_changed.connect(_number_changed.bind(property, label_text, integer, options))
	_add_property_row(label_text, tooltip, control)
	_bindings.append({
		"property": property,
		"kind": "number",
		"control": control,
		"options": options,
	})
	_tag_property_control(control, property, &"number")
	return control


func add_vector2_property(
		property: StringName,
		label_text: String,
		tooltip := "",
		options: Dictionary = {},
) -> HBoxContainer:
	return _add_vector_property(property, label_text, 2, tooltip, options)


func add_vector3_property(
		property: StringName,
		label_text: String,
		tooltip := "",
		options: Dictionary = {},
) -> HBoxContainer:
	return _add_vector_property(property, label_text, 3, tooltip, options)


func add_enum_property(
		property: StringName,
		label_text: String,
		items: PackedStringArray,
		tooltip := "",
		values: Array = [],
	) -> OptionButton:
	var control := OptionButton.new()
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		control.add_item(tr(item))
	var resolved_values := values.duplicate()
	if resolved_values.is_empty():
		for index in items.size():
			resolved_values.append(index)
	control.select(resolved_values.find(model.get(property)))
	control.item_selected.connect(_enum_changed.bind(property, label_text, resolved_values))
	_add_property_row(label_text, tooltip, control)
	_bindings.append({
		"property": property,
		"kind": "enum",
		"control": control,
		"values": resolved_values,
	})
	_tag_property_control(control, property, &"enum")
	return control


func add_color_property(
		property: StringName,
		label_text: String,
		tooltip := "",
		force_opaque := false,
) -> ColorPickerButton:
	var control := ColorPickerButton.new()
	var color: Color = model.get(property)
	if force_opaque:
		color.a = 1.0
	control.color = color
	control.edit_alpha = not force_opaque
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.color_changed.connect(_color_changed.bind(property, label_text, force_opaque))
	_add_property_row(label_text, tooltip, control)
	_bindings.append({
		"property": property,
		"kind": "color",
		"control": control,
		"force_opaque": force_opaque,
	})
	_tag_property_control(control, property, &"color")
	return control


func add_path_property(property: StringName, label_text: String, tooltip := "") -> LineEdit:
	var control := _add_line_edit(property, label_text, tooltip)
	control.text = _path_to_text(model.get(property))
	_bindings.append({"property": property, "kind": "path", "control": control})
	_tag_property_control(control, property, &"path")
	return control


func add_text_property(
		property: StringName,
		label_text: String,
		tooltip := "",
		options: Dictionary = {},
) -> LineEdit:
	var control := _add_line_edit(property, label_text, tooltip)
	control.text = String(model.get(property))
	control.placeholder_text = options.get("placeholder", "")
	control.secret = options.get("secret", false)
	_bindings.append({"property": property, "kind": "text", "control": control})
	_tag_property_control(control, property, &"text")
	return control


func add_suggestion_property(
		property: StringName,
		label_text: String,
		suggestions: PackedStringArray,
		tooltip := "",
) -> LineEdit:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var control := _make_line_edit(property, label_text)
	control.text = String(model.get(property))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	var menu := MenuButton.new()
	menu.text = tr("Choose")
	menu.tooltip_text = tr("Choose a suggested value")
	for index in suggestions.size():
		menu.get_popup().add_item(tr(suggestions[index]), index)
	menu.get_popup().id_pressed.connect(
		_suggestion_selected.bind(control, property, label_text, suggestions),
	)
	row.add_child(menu)
	_add_property_row(label_text, tooltip, row)
	_bindings.append({"property": property, "kind": "text", "control": control})
	_tag_property_control(control, property, &"suggestion")
	return control


func add_multiline_property(property: StringName, label_text: String, tooltip := "") -> TextEdit:
	var control := TextEdit.new()
	control.text = String(model.get(property))
	control.custom_minimum_size.y = 72.0
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.focus_exited.connect(_multiline_focus_exited.bind(control, property, label_text))
	_add_property_row(label_text, tooltip, control)
	_bindings.append({"property": property, "kind": "multiline", "control": control})
	_tag_property_control(control, property, &"multiline")
	return control


func add_file_property(
		property: StringName,
		label_text: String,
		tooltip := "",
		options: Dictionary = {},
) -> LineEdit:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var control := _make_line_edit(property, label_text)
	control.text = String(model.get(property))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	var browse := Button.new()
	browse.text = "..."
	browse.tooltip_text = tr("Browse")
	browse.set_meta(&"scatter_file_options", options)
	browse.pressed.connect(_browse_path.bind(control, property, label_text, options))
	row.add_child(browse)
	_add_property_row(label_text, tooltip, row)
	_bindings.append({"property": property, "kind": "text", "control": control})
	_tag_property_control(control, property, &"file")
	return control


func add_node_path_property(property: StringName, label_text: String, tooltip := "") -> LineEdit:
	var control := _add_line_edit(property, label_text, tooltip)
	control.text = String(model.get(property))
	_bindings.append({"property": property, "kind": "node_path", "control": control})
	_tag_property_control(control, property, &"node_path")
	return control


func add_bitmask_property(
		property: StringName,
		label_text: String,
		items: Array[Dictionary],
		tooltip := "",
) -> MenuButton:
	var control := MenuButton.new()
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var popup := control.get_popup()
	popup.hide_on_checkable_item_selection = false
	for index in items.size():
		popup.add_check_item(tr(String(items[index].label)), index)
	popup.id_pressed.connect(_bitmask_item_pressed.bind(control, property, label_text, items))
	_add_property_row(label_text, tooltip, control)
	_sync_bitmask_control(control, int(model.get(property)), items)
	_bindings.append({
		"property": property,
		"kind": "bitmask",
		"control": control,
		"items": items,
	})
	_tag_property_control(control, property, &"bitmask")
	return control


func add_property_category(label_text: String) -> Control:
	return _add_property_section(&"category", label_text, 0.0)


func add_property_group(label_text: String) -> Control:
	return _add_property_section(&"group", label_text, 6.0)


func add_property_subgroup(label_text: String) -> Control:
	return _add_property_section(&"subgroup", label_text, 18.0)


func set_property_control_editable(control: Control, editable: bool) -> void:
	if control is SpinBox:
		control.editable = editable
	elif control is LineEdit:
		control.editable = editable
	elif control is TextEdit:
		control.editable = editable
	elif control is BaseButton:
		control.disabled = not editable
	for child in control.get_children():
		if child is Control:
			set_property_control_editable(child, editable)


func _add_seed_controls() -> void:
	var row := HBoxContainer.new()
	var override_control := CheckBox.new()
	var seed_control := SpinBox.new()
	override_control.text = tr("Independent Seed")
	override_control.tooltip_text = tr("Use a fixed seed for this node")
	override_control.button_pressed = model.override_seed
	override_control.toggled.connect(_seed_override_changed.bind(seed_control))
	row.add_child(override_control)
	seed_control.min_value = -2147483648
	seed_control.max_value = 2147483647
	seed_control.step = 1
	seed_control.value = model.custom_seed
	seed_control.visible = model.override_seed
	seed_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_control.value_changed.connect(_number_changed.bind(&"custom_seed", "Independent Seed", true))
	row.add_child(seed_control)
	add_child(row)
	_bindings.append({"property": &"override_seed", "kind": "bool", "control": override_control})
	_bindings.append({"property": &"custom_seed", "kind": "number", "control": seed_control})


func _add_vector_property(
		property: StringName,
		label_text: String,
		count: int,
		tooltip: String,
		options: Dictionary,
	) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var controls: Array[SpinBox] = []
	var value = model.get(property)
	for axis in count:
		var control := SpinBox.new()
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.custom_minimum_size.x = 150
		control.min_value = -1000000.0
		control.max_value = 1000000.0
		control.step = 0.05
		control.allow_lesser = true
		control.allow_greater = true
		control.suffix = options.get("suffix", "")
		control.value = _number_to_display(value[axis], options)
		control.prefix = ["X ", "Y ", "Z "][axis]
		control.value_changed.connect(_vector_changed.bind(property, label_text, axis, count, options))
		box.add_child(control)
		controls.append(control)
	_add_property_row(label_text, tooltip, box)
	_bindings.append({
		"property": property,
		"kind": "vector2" if count == 2 else "vector3",
		"controls": controls,
		"options": options,
	})
	_tag_property_control(box, property, &"vector2" if count == 2 else &"vector3")
	return box


func _add_line_edit(property: StringName, label_text: String, tooltip: String) -> LineEdit:
	var control := _make_line_edit(property, label_text)
	_add_property_row(label_text, tooltip, control)
	return control


func _make_line_edit(property: StringName, label_text: String) -> LineEdit:
	var control := LineEdit.new()
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.text_submitted.connect(_text_submitted.bind(property, label_text))
	control.focus_exited.connect(_text_focus_exited.bind(control, property, label_text))
	return control


func _add_property_row(label_text: String, tooltip: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = tr(label_text)
	label.custom_minimum_size.x = 84
	label.tooltip_text = tr(tooltip) if tooltip != "" else ""
	control.tooltip_text = label.tooltip_text
	row.add_child(label)
	row.add_child(control)
	add_child(row)


func _add_property_section(kind: StringName, label_text: String, indentation: float) -> Control:
	var margin := MarginContainer.new()
	margin.set_meta(&"scatter_property_section", kind)
	margin.set_meta(&"scatter_property_label", label_text)
	margin.add_theme_constant_override(&"margin_left", int(indentation))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	var label := Label.new()
	label.text = tr(label_text)
	label.set_meta(&"scatter_property_section", kind)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(label)
	if kind == &"category":
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var separator := HSeparator.new()
		separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(separator)
	elif kind == &"subgroup":
		label.modulate.a = 0.78
	margin.add_child(row)
	add_child(margin)
	return margin


func _enabled_changed(value: bool) -> void:
	if _syncing:
		return
	context.commit_property(model, &"enabled", value, tr("Node Enabled"))


func _bool_changed(value: bool, property: StringName, caption: String) -> void:
	if _syncing:
		return
	context.commit_property(model, property, value, tr(caption))


func _number_changed(
		value: float,
		property: StringName,
		caption: String,
		integer: bool,
		options: Dictionary = {},
) -> void:
	if _syncing:
		return
	var stored_value := _number_from_display(value, options)
	context.commit_property(
		model,
		property,
		int(stored_value) if integer else stored_value,
		tr(caption),
		"",
		UndoRedo.MERGE_ENDS,
	)


func _vector_changed(
		value: float,
		property: StringName,
		caption: String,
		axis: int,
		count: int,
		options: Dictionary = {},
) -> void:
	if _syncing:
		return
	var vector = model.get(property)
	vector[axis] = _number_from_display(value, options)
	context.commit_property(
		model,
		property,
		vector,
		tr(caption),
		["X", "Y", "Z"][axis],
		UndoRedo.MERGE_ENDS,
	)


func _enum_changed(index: int, property: StringName, caption: String, values: Array = []) -> void:
	if _syncing:
		return
	var value: Variant = values[index] if index >= 0 and index < values.size() else index
	context.commit_property(model, property, value, tr(caption))


func _color_changed(
		value: Color,
		property: StringName,
		caption: String,
		force_opaque := false,
) -> void:
	if _syncing:
		return
	if force_opaque:
		value.a = 1.0
	context.commit_property(model, property, value, tr(caption), "", UndoRedo.MERGE_ENDS)


func _seed_override_changed(value: bool, seed_control: SpinBox) -> void:
	seed_control.visible = value
	_bool_changed(value, &"override_seed", "Independent Seed")


func _text_submitted(text: String, property: StringName, caption: String) -> void:
	_commit_text(text, property, caption)


func _text_focus_exited(control: LineEdit, property: StringName, caption: String) -> void:
	_commit_text(control.text, property, caption)


func _multiline_focus_exited(control: TextEdit, property: StringName, caption: String) -> void:
	_commit_text(control.text, property, caption)


func _suggestion_selected(
		index: int,
		control: LineEdit,
		property: StringName,
		caption: String,
		suggestions: PackedStringArray,
) -> void:
	if index < 0 or index >= suggestions.size():
		return
	control.text = suggestions[index]
	_commit_text(control.text, property, caption)


func _bitmask_item_pressed(
		index: int,
		control: MenuButton,
		property: StringName,
		caption: String,
		items: Array[Dictionary],
) -> void:
	if _syncing or index < 0 or index >= items.size():
		return
	var value := int(model.get(property)) ^ int(items[index].value)
	context.commit_property(model, property, value, tr(caption))
	_sync_bitmask_control(control, value, items)


func _sync_bitmask_control(control: MenuButton, value: int, items: Array[Dictionary]) -> void:
	var popup := control.get_popup()
	var selected := PackedStringArray()
	for index in items.size():
		var mask := int(items[index].value)
		var checked := mask != 0 and (value & mask) == mask
		popup.set_item_checked(index, checked)
		if checked:
			selected.append(tr(String(items[index].label)))
	if selected.is_empty():
		control.text = tr("None")
	elif selected.size() <= 3:
		control.text = ", ".join(selected)
	else:
		control.text = tr("%d selected") % selected.size()


func _browse_path(
		control: LineEdit,
		property: StringName,
		caption: String,
		options: Dictionary,
) -> void:
	var dialog := FileDialog.new()
	dialog.title = tr("Choose %s") % tr(caption)
	dialog.access = int(options.get("access", FileDialog.ACCESS_RESOURCES))
	dialog.file_mode = int(options.get("file_mode", FileDialog.FILE_MODE_OPEN_FILE))
	var filters: PackedStringArray = options.get("filters", PackedStringArray())
	if not filters.is_empty():
		dialog.filters = filters
	if not control.text.is_empty() and not control.text.begins_with("uid://"):
		dialog.current_path = control.text
	dialog.file_selected.connect(_path_selected.bind(control, property, caption, dialog))
	dialog.dir_selected.connect(_path_selected.bind(control, property, caption, dialog))
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _path_selected(
		path: String,
		control: LineEdit,
		property: StringName,
		caption: String,
		dialog: FileDialog,
) -> void:
	control.text = path
	_commit_text(path, property, caption)
	dialog.queue_free()


func _commit_text(text: String, property: StringName, caption: String) -> void:
	if _syncing:
		return
	var current = model.get(property)
	var value: Variant = text
	if current is PackedVector3Array:
		value = _text_to_path(text)
	elif current is NodePath:
		value = NodePath(text)
	elif current is StringName:
		value = StringName(text)
	context.commit_property(model, property, value, tr(caption))


func _tag_property_control(control: Control, property: StringName, kind: StringName) -> void:
	control.set_meta(&"scatter_property", property)
	control.set_meta(&"scatter_property_kind", kind)


static func _number_to_display(value: float, options: Dictionary) -> float:
	return value * float(options.get("display_scale", 1.0))


static func _number_from_display(value: float, options: Dictionary) -> float:
	var scale := float(options.get("display_scale", 1.0))
	return value / scale if not is_zero_approx(scale) else value


func _tint_native_titlebar(color: Color) -> void:
	var normal := get_theme_stylebox("titlebar")
	if normal is StyleBoxFlat:
		var tinted := normal.duplicate() as StyleBoxFlat
		tinted.bg_color = color.darkened(0.38)
		add_theme_stylebox_override("titlebar", tinted)
	var selected_style := get_theme_stylebox("titlebar_selected")
	if selected_style is StyleBoxFlat:
		var tinted_selected := selected_style.duplicate() as StyleBoxFlat
		tinted_selected.bg_color = color.darkened(0.27)
		add_theme_stylebox_override("titlebar_selected", tinted_selected)


static func _port_signature(port: ScatterPort, is_output: bool) -> Array:
	return [
		is_output,
		port.id,
		port.label,
		port.type_id,
		port.visual_type_id,
		port.variadic,
		port.connectable,
		port.visible,
	]


static func _path_to_text(points: PackedVector3Array) -> String:
	var parts: PackedStringArray = []
	for point in points:
		parts.append("%s,%s,%s" % [point.x, point.y, point.z])
	return "; ".join(parts)


static func _text_to_path(text: String) -> PackedVector3Array:
	var result := PackedVector3Array()
	for raw_point in text.split(";", false):
		var values := raw_point.strip_edges().split(",", false)
		if values.size() == 3:
			result.append(Vector3(values[0].to_float(), values[1].to_float(), values[2].to_float()))
	return result
