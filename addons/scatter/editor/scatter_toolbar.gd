@tool
class_name ScatterToolbar
extends VBoxContainer

signal add_requested
signal focus_requested
signal output_requested
signal save_requested
signal load_requested
signal build_requested
signal seed_changed(value: int)
signal reroll_requested
signal auto_build_changed(value: bool)
signal collision_mask_changed(value: int)
signal paint_changed(value: bool)
signal erase_changed(value: bool)
signal brush_radius_changed(value: float)
signal clear_paint_requested

var _title: Label
var _seed: SpinBox
var _auto_build: CheckBox
var _collision_mask: SpinBox
var _paint: Button
var _erase: Button
var _brush_radius: SpinBox
var _clear_paint: Button
var _syncing := false


func _ready() -> void:
	_build_actions()
	_build_settings()


func set_title(value: String) -> void:
	_title.text = value


func set_editor_enabled(value: bool) -> void:
	for row in get_children():
		for control in row.get_children():
			if control is BaseButton:
				control.disabled = not value
			elif control is SpinBox:
				control.editable = value


func sync_graph(seed: int, auto_build: bool, collision_mask: int, radius: float) -> void:
	_syncing = true
	_seed.value = seed
	_auto_build.button_pressed = auto_build
	_collision_mask.value = collision_mask
	_brush_radius.value = radius
	_syncing = false


func sync_paint(active: bool, erase: bool, has_layer: bool) -> void:
	_paint.set_pressed_no_signal(active)
	_erase.set_pressed_no_signal(erase)
	_erase.disabled = not active
	_clear_paint.disabled = not has_layer


func reject_paint_toggle() -> void:
	_paint.set_pressed_no_signal(false)


func _build_actions() -> void:
	var row := HBoxContainer.new()
	add_child(row)
	_title = Label.new()
	_title.text = tr("Scatter")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title)
	_add_button(row, "Add Node", add_requested.emit, "Add a node to the Scatter graph")
	_add_button(row, "Focus", focus_requested.emit)
	_add_button(row, "Output", output_requested.emit)
	_add_button(row, "Save Recipe", save_requested.emit)
	_add_button(row, "Load Recipe", load_requested.emit)
	_add_button(row, "Build", build_requested.emit, "Evaluate the graph and write the MultiMesh instance buffer")


func _build_settings() -> void:
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(_label("Seed"))
	_seed = _spin(-2147483648.0, 2147483647.0, 1.0)
	_seed.custom_minimum_size.x = 100
	_seed.value_changed.connect(func(value: float):
		if not _syncing: seed_changed.emit(int(value))
	)
	row.add_child(_seed)
	_add_button(row, "Reroll", reroll_requested.emit)
	_auto_build = CheckBox.new()
	_auto_build.text = tr("Auto Build")
	_auto_build.toggled.connect(func(value: bool):
		if not _syncing: auto_build_changed.emit(value)
	)
	row.add_child(_auto_build)
	row.add_child(_label("Collision Mask"))
	_collision_mask = _spin(1.0, 4294967295.0, 1.0)
	_collision_mask.custom_minimum_size.x = 90
	_collision_mask.value_changed.connect(func(value: float):
		if not _syncing: collision_mask_changed.emit(int(value))
	)
	row.add_child(_collision_mask)
	row.add_child(VSeparator.new())
	_paint = _toggle_button("Paint")
	_paint.toggled.connect(func(value: bool): paint_changed.emit(value))
	row.add_child(_paint)
	_erase = _toggle_button("Erase")
	_erase.toggled.connect(func(value: bool): erase_changed.emit(value))
	row.add_child(_erase)
	row.add_child(_label("Radius"))
	_brush_radius = _spin(0.05, 1000.0, 0.05)
	_brush_radius.value_changed.connect(func(value: float): brush_radius_changed.emit(value))
	row.add_child(_brush_radius)
	_clear_paint = _add_button(row, "Clear Layer", clear_paint_requested.emit)


func _add_button(parent: Container, caption: String, callback: Callable, tooltip := "") -> Button:
	var button := Button.new()
	button.text = tr(caption)
	button.tooltip_text = tr(tooltip) if tooltip != "" else ""
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _toggle_button(caption: String) -> Button:
	var button := Button.new()
	button.text = tr(caption)
	button.toggle_mode = true
	return button


func _label(caption: String) -> Label:
	var label := Label.new()
	label.text = tr(caption)
	return label


func _spin(minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.allow_greater = false
	spin.allow_lesser = false
	return spin
