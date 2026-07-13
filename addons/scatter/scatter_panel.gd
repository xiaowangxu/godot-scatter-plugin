@tool
class_name ScatterPanel
extends VBoxContainer

signal build_requested
signal recipe_changed
signal paint_mode_changed(active: bool)

var target: MultiMeshInstance3D
var config: ScatterConfig
var paint_active := false
var paint_erase := false
var brush_radius := 2.0
var active_paint_node_id := 0

var _title_label: Label
var _status_label: Label
var _paint_layer_label: Label
var _graph: GraphEdit
var _add_popup: PopupMenu
var _popup_types: Dictionary = {}
var _seed: SpinBox
var _auto_rebuild: CheckBox
var _paint_button: Button
var _erase_button: Button
var _clear_paint_button: Button
var _paint_count_labels: Dictionary = {}
var _output_stats_label: Label
var _updating := false
var _save_dialog: FileDialog
var _load_dialog: FileDialog


func _ready() -> void:
	custom_minimum_size = Vector2(0, 430)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_toolbar()
	_graph = GraphEdit.new()
	_graph.name = "RecipeGraph"
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.show_grid = true
	_graph.minimap_enabled = true
	_graph.minimap_size = Vector2(190, 120)
	_graph.right_disconnects = true
	_graph.add_valid_connection_type(ScatterSchema.REGION_PORT_TYPE, ScatterSchema.REGION_PORT_TYPE)
	_graph.add_valid_connection_type(ScatterSchema.PLACEMENT_PORT_TYPE, ScatterSchema.PLACEMENT_PORT_TYPE)
	_graph.connection_request.connect(_connection_requested)
	_graph.disconnection_request.connect(_disconnection_requested)
	_graph.node_selected.connect(_graph_node_selected)
	add_child(_graph)

	_status_label = Label.new()
	_status_label.text = "请选择一个 MultiMeshInstance3D 开始编辑。"
	_status_label.tooltip_text = "配方保存在原生 MultiMeshInstance3D 的元数据中，不会创建额外场景节点。"
	add_child(_status_label)


func _build_toolbar() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	add_child(top)

	_title_label = Label.new()
	_title_label.text = "Scatter 散布"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 16)
	top.add_child(_title_label)

	var seed_label := Label.new()
	seed_label.text = "全局种子"
	seed_label.tooltip_text = "相同配方与种子会产生完全相同的实例数据。"
	top.add_child(seed_label)
	_seed = SpinBox.new()
	_seed.min_value = -2147483648
	_seed.max_value = 2147483647
	_seed.step = 1
	_seed.custom_minimum_size.x = 108
	_seed.tooltip_text = seed_label.tooltip_text
	_seed.value_changed.connect(_on_seed_changed)
	top.add_child(_seed)

	var reroll := Button.new()
	reroll.text = "↻"
	reroll.tooltip_text = "随机一个新种子并重新生成"
	reroll.pressed.connect(_on_reroll)
	top.add_child(reroll)

	_auto_rebuild = CheckBox.new()
	_auto_rebuild.text = "自动预览"
	_auto_rebuild.tooltip_text = "参数或连线改变时立即更新 3D 视口中的 MultiMesh。"
	_auto_rebuild.toggled.connect(_on_auto_rebuild_toggled)
	top.add_child(_auto_rebuild)

	var add := Button.new()
	add.text = "＋ 添加节点"
	add.tooltip_text = "添加 Region、Placement 或实例处理节点"
	add.pressed.connect(_show_add_popup.bind(add))
	top.add_child(add)
	_add_popup = PopupMenu.new()
	add_child(_add_popup)
	var item_id := 1
	for category in ScatterSchema.CATEGORIES:
		_add_popup.add_separator(category)
		for type in ScatterSchema.CATEGORIES[category]:
			_add_popup.add_item(ScatterSchema.display_title(type), item_id)
			_add_popup.set_item_tooltip(_add_popup.item_count - 1, ScatterSchema.description(type))
			_popup_types[item_id] = type
			item_id += 1
	_add_popup.id_pressed.connect(_on_add_type)

	var generate := Button.new()
	generate.text = "生成预览"
	generate.tooltip_text = "沿 Output 当前连接重新生成 MultiMesh 实例数据"
	generate.pressed.connect(func(): build_requested.emit())
	top.add_child(generate)

	var focus := Button.new()
	focus.text = "定位输出"
	focus.tooltip_text = "把图视图移动到 Output 节点"
	focus.pressed.connect(focus_output)
	top.add_child(focus)

	var save := Button.new()
	save.text = "保存配方"
	save.tooltip_text = "把当前连线图保存为可复用的 .tres 资源"
	save.pressed.connect(_save_recipe)
	top.add_child(save)
	var load_recipe := Button.new()
	load_recipe.text = "载入配方"
	load_recipe.tooltip_text = "从 .tres 替换当前程序化配方"
	load_recipe.pressed.connect(_load_recipe)
	top.add_child(load_recipe)

	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_dialog.add_filter("*.tres", "Scatter Recipe")
	_save_dialog.file_selected.connect(_recipe_file_selected)
	add_child(_save_dialog)
	_load_dialog = FileDialog.new()
	_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_load_dialog.access = FileDialog.ACCESS_RESOURCES
	_load_dialog.add_filter("*.tres", "Scatter Recipe")
	_load_dialog.file_selected.connect(_load_recipe_file)
	add_child(_load_dialog)

	var paint_bar := HBoxContainer.new()
	paint_bar.add_theme_constant_override("separation", 8)
	add_child(paint_bar)
	_paint_layer_label = Label.new()
	_paint_layer_label.text = "绘制图层：请选中 Paint Region 节点"
	_paint_layer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_layer_label.tooltip_text = "每个 Paint Region 节点都是独立图层；可用 Region 运算节点组合多个绘制图层。"
	paint_bar.add_child(_paint_layer_label)

	_paint_button = Button.new()
	_paint_button.text = "绘制区域"
	_paint_button.toggle_mode = true
	_paint_button.tooltip_text = "在 3D 视口碰撞表面绘制当前 Paint Region 图层（左键）"
	_paint_button.toggled.connect(_on_paint_toggled)
	paint_bar.add_child(_paint_button)
	_erase_button = Button.new()
	_erase_button.text = "擦除区域"
	_erase_button.toggle_mode = true
	_erase_button.tooltip_text = "从当前 Paint Region 图层擦除笔刷范围内的笔触"
	_erase_button.toggled.connect(_on_erase_toggled)
	paint_bar.add_child(_erase_button)
	_clear_paint_button = Button.new()
	_clear_paint_button.text = "清空图层"
	_clear_paint_button.tooltip_text = "删除当前 Paint Region 节点保存的全部笔触"
	_clear_paint_button.pressed.connect(_clear_active_paint)
	paint_bar.add_child(_clear_paint_button)

	var radius_label := Label.new()
	radius_label.text = "笔刷半径"
	radius_label.tooltip_text = "视口预览圆环与新笔触的半径。"
	paint_bar.add_child(radius_label)
	var radius := SpinBox.new()
	radius.min_value = 0.05
	radius.max_value = 1000
	radius.step = 0.1
	radius.value = brush_radius
	radius.custom_minimum_size.x = 95
	radius.tooltip_text = radius_label.tooltip_text
	radius.value_changed.connect(_brush_radius_changed)
	paint_bar.add_child(radius)

	var collision_label := Label.new()
	collision_label.text = "碰撞层"
	collision_label.tooltip_text = "绘制笔刷射线检测的物理碰撞层遮罩。"
	paint_bar.add_child(collision_label)
	var collision := SpinBox.new()
	collision.name = "PaintCollisionMask"
	collision.min_value = 0
	collision.max_value = 4294967295
	collision.step = 1
	collision.value_changed.connect(_collision_mask_changed)
	collision.custom_minimum_size.x = 92
	collision.tooltip_text = collision_label.tooltip_text
	paint_bar.add_child(collision)


func set_target(value: MultiMeshInstance3D) -> void:
	target = value
	_stop_painting()
	if not is_instance_valid(target):
		config = null
		_title_label.text = "Scatter 散布"
		_status_label.text = "请选择一个 MultiMeshInstance3D 开始编辑。"
		_clear_graph()
		return
	config = ScatterGenerator.ensure_config(target)
	_title_label.text = "Scatter 散布 — %s" % target.name
	_updating = true
	_seed.value = config.seed
	_auto_rebuild.button_pressed = config.auto_rebuild
	var collision := get_node_or_null("PaintCollisionMask") as SpinBox
	if collision == null:
		collision = find_child("PaintCollisionMask", true, false) as SpinBox
	if collision != null: collision.value = config.collision_mask
	_updating = false
	if config.nodes.is_empty():
		_create_starter_recipe()
		build_requested.emit()
	else:
		config.ensure_graph()
	rebuild_graph()
	update_status()


func _create_starter_recipe() -> void:
	config.add_node(&"shape_box", Vector2(80, 330))
	config.add_node(&"create_random", Vector2(80, 60))
	config.add_node(&"random_rotation", Vector2(420, 60))
	var scale_node := config.add_node(&"random_transform", Vector2(760, 60))
	scale_node.params.scale = Vector3(0.2, 0.2, 0.2)
	config.ensure_graph()
	var output := config.output_node()
	if not output.is_empty(): output.position = Vector2(1160, 190)
	config.emit_changed()


func rebuild_graph() -> void:
	if not is_node_ready(): return
	_updating = true
	_clear_graph()
	_paint_count_labels.clear()
	_output_stats_label = null
	if config == null:
		_updating = false
		return
	config.ensure_graph()
	for entry in config.nodes:
		var graph_node := _make_graph_node(entry)
		_graph.add_child(graph_node)
	for connection in config.connections:
		var from_name := StringName(str(connection.get("from_id", 0)))
		var to_name := StringName(str(connection.get("to_id", 0)))
		if _graph.has_node(NodePath(String(from_name))) and _graph.has_node(NodePath(String(to_name))):
			_graph.connect_node(from_name, int(connection.get("from_port", 0)), to_name, int(connection.get("to_port", 0)))
	_updating = false
	_update_active_paint_ui()
	update_status()
	focus_recipe.call_deferred()


func focus_recipe() -> void:
	if _graph == null: return
	_graph.zoom = 0.85
	_graph.scroll_offset = Vector2.ZERO


func focus_output() -> void:
	if config == null: return
	var output := config.output_node()
	if output.is_empty(): return
	_graph.zoom = 0.9
	var output_position: Vector2 = output.get("position", Vector2.ZERO)
	_graph.scroll_offset = output_position - _graph.size * 0.55


func _make_graph_node(entry: Dictionary) -> GraphNode:
	var id := int(entry.get("id", 0))
	var type := StringName(entry.get("type", ""))
	var definition := ScatterSchema.definition(type)
	var node := GraphNode.new()
	node.name = str(id)
	node.title = ScatterSchema.display_title(type)
	node.tooltip_text = ScatterSchema.description(type)
	node.position_offset = entry.get("position", Vector2.ZERO)
	node.custom_minimum_size.x = 305 if type != &"output" else 330
	node.position_offset_changed.connect(_node_moved.bind(id, node))
	node.delete_request.connect(_delete_node.bind(id))
	_apply_node_theme(node, definition.get("color", Color.GRAY), type == &"output")

	var info := HBoxContainer.new()
	var type_badge := Label.new()
	type_badge.text = "REGION" if ScatterSchema.is_region(type) else ("OUTPUT" if type == &"output" else "PLACEMENT")
	type_badge.modulate = ScatterSchema.REGION_COLOR if ScatterSchema.is_region(type) else (Color("e8b968") if type == &"output" else ScatterSchema.PLACEMENT_COLOR)
	type_badge.tooltip_text = ScatterSchema.description(type)
	info.add_child(type_badge)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(spacer)
	if type != &"output":
		var enabled := CheckBox.new()
		enabled.text = "启用"
		enabled.button_pressed = entry.get("enabled", true)
		enabled.tooltip_text = "关闭后该节点不参与求值；Placement 节点会直接传递上游数据。"
		enabled.toggled.connect(_enabled_changed.bind(id))
		info.add_child(enabled)
		var remove := Button.new()
		remove.text = "删除"
		remove.flat = true
		remove.tooltip_text = "删除此节点及与它相连的线"
		remove.pressed.connect(_delete_node.bind(id))
		info.add_child(remove)
	node.add_child(info)

	if type == &"output":
		_add_output_rows(node)
		return node
	if ScatterSchema.is_region_source(type):
		_add_region_source_rows(node, entry)
	elif ScatterSchema.is_region_operator(type):
		_add_binary_rows(node, ScatterSchema.REGION_PORT_TYPE, ScatterSchema.REGION_COLOR, "区域 A", "区域 B", "组合区域")
	elif type == &"placement_merge":
		_add_binary_rows(node, ScatterSchema.PLACEMENT_PORT_TYPE, ScatterSchema.PLACEMENT_COLOR, "布点 A", "布点 B", "合并布点")
	else:
		_add_flow_row(node, ScatterSchema.PLACEMENT_PORT_TYPE, ScatterSchema.PLACEMENT_COLOR, "Placement  实例流")

	if ScatterSchema.is_placement(type) and type != &"placement_merge":
		_add_seed_row(node, entry)
	_add_parameter_rows(node, entry, definition)
	return node


func _apply_node_theme(node: GraphNode, color: Color, is_output: bool) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("20242b") if not is_output else Color("2b281f")
	panel.border_color = Color(color, 0.9)
	panel.set_border_width_all(1 if not is_output else 2)
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 10
	panel.content_margin_right = 10
	panel.content_margin_bottom = 9
	node.add_theme_stylebox_override("panel", panel)
	var selected := panel.duplicate() as StyleBoxFlat
	selected.border_color = color.lightened(0.25)
	selected.set_border_width_all(3)
	node.add_theme_stylebox_override("panel_selected", selected)
	var titlebar := StyleBoxFlat.new()
	titlebar.bg_color = color.darkened(0.58)
	titlebar.set_corner_radius_all(8)
	titlebar.corner_radius_bottom_left = 0
	titlebar.corner_radius_bottom_right = 0
	titlebar.content_margin_left = 10
	titlebar.content_margin_right = 10
	titlebar.content_margin_top = 6
	titlebar.content_margin_bottom = 6
	node.add_theme_stylebox_override("titlebar", titlebar)
	node.add_theme_stylebox_override("titlebar_selected", titlebar)


func _add_output_rows(node: GraphNode) -> void:
	var intro := Label.new()
	intro.text = "Region 定义在哪里散布\nPlacement 定义怎样生成实例"
	intro.tooltip_text = ScatterSchema.description(&"output")
	node.add_child(intro)
	var region_row := Label.new()
	region_row.text = "Region  区域"
	region_row.tooltip_text = "连接一个 Region 源或 Region 运算结果"
	node.add_child(region_row)
	node.set_slot(1, true, ScatterSchema.REGION_PORT_TYPE, ScatterSchema.REGION_COLOR, false, 0, Color.WHITE)
	var placement_row := Label.new()
	placement_row.text = "Placement  布点"
	placement_row.tooltip_text = "连接一条 Placement 数据流"
	node.add_child(placement_row)
	node.set_slot(2, true, ScatterSchema.PLACEMENT_PORT_TYPE, ScatterSchema.PLACEMENT_COLOR, false, 0, Color.WHITE)
	_output_stats_label = Label.new()
	_output_stats_label.text = "等待生成预览"
	_output_stats_label.modulate = Color("bfc5cf")
	node.add_child(_output_stats_label)


func _add_region_source_rows(node: GraphNode, entry: Dictionary) -> void:
	var id := int(entry.get("id", 0))
	if entry.get("type", "") == "paint_region":
		var paint_actions := HBoxContainer.new()
		var activate := Button.new()
		activate.text = "在视口绘制"
		activate.tooltip_text = "把这个绘制图层设为当前图层并启用 3D 笔刷"
		activate.pressed.connect(_activate_paint_node.bind(id, true))
		paint_actions.add_child(activate)
		var count := Label.new()
		count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		paint_actions.add_child(count)
		_paint_count_labels[id] = count
		node.add_child(paint_actions)
		_update_paint_count(id)
	var output_row := Label.new()
	output_row.text = "区域输出  Region"
	output_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	output_row.tooltip_text = "连接到 Region 运算节点或 Output.Region"
	node.add_child(output_row)
	node.set_slot(node.get_child_count() - 1, false, 0, Color.WHITE, true, ScatterSchema.REGION_PORT_TYPE, ScatterSchema.REGION_COLOR)


func _add_binary_rows(node: GraphNode, port_type: int, color: Color, a_text: String, b_text: String, output_text: String) -> void:
	var a := Label.new()
	a.text = a_text
	a.tooltip_text = "第一个输入"
	node.add_child(a)
	node.set_slot(node.get_child_count() - 1, true, port_type, color, false, 0, Color.WHITE)
	var b := Label.new()
	b.text = b_text
	b.tooltip_text = "第二个输入"
	node.add_child(b)
	node.set_slot(node.get_child_count() - 1, true, port_type, color, false, 0, Color.WHITE)
	var output := Label.new()
	output.text = output_text
	output.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	node.add_child(output)
	node.set_slot(node.get_child_count() - 1, false, 0, Color.WHITE, true, port_type, color)


func _add_flow_row(node: GraphNode, port_type: int, color: Color, text: String) -> void:
	var row := Label.new()
	row.text = text
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.tooltip_text = "左侧接收上游数据，右侧输出处理后的实例数据。没有上游时从空数据开始。"
	node.add_child(row)
	node.set_slot(node.get_child_count() - 1, true, port_type, color, true, port_type, color)


func _add_seed_row(node: GraphNode, entry: Dictionary) -> void:
	var id := int(entry.get("id", 0))
	var row := HBoxContainer.new()
	var override_seed := CheckBox.new()
	override_seed.text = "独立种子"
	override_seed.tooltip_text = "为此节点使用独立固定种子"
	override_seed.button_pressed = entry.get("override_seed", false)
	row.add_child(override_seed)
	var custom_seed := SpinBox.new()
	custom_seed.min_value = -2147483648
	custom_seed.max_value = 2147483647
	custom_seed.step = 1
	custom_seed.value = entry.get("custom_seed", 0)
	custom_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_seed.visible = override_seed.button_pressed
	custom_seed.tooltip_text = "该节点的固定随机种子"
	custom_seed.value_changed.connect(_custom_seed_changed.bind(id))
	override_seed.toggled.connect(_override_seed_changed.bind(id, custom_seed))
	row.add_child(custom_seed)
	node.add_child(row)


func _add_parameter_rows(node: GraphNode, entry: Dictionary, definition: Dictionary) -> void:
	var id := int(entry.get("id", 0))
	var params: Dictionary = entry.get("params", {})
	for key in definition.get("params", {}):
		var spec: Dictionary = definition.params[key]
		if spec.get("hidden", false): continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = ScatterSchema.parameter_label(key)
		label.custom_minimum_size.x = 108
		label.tooltip_text = ScatterSchema.parameter_tooltip(key)
		row.add_child(label)
		var control := _make_parameter_control(id, key, spec, params.get(key, spec.get("default")))
		control.tooltip_text = label.tooltip_text
		row.add_child(control)
		node.add_child(row)


func _make_parameter_control(id: int, key: String, spec: Dictionary, value: Variant) -> Control:
	var type := String(spec.get("type", ""))
	match type:
		"bool":
			var control := CheckBox.new()
			control.button_pressed = value
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			control.toggled.connect(_parameter_changed.bind(id, key))
			return control
		"float", "int":
			var control := SpinBox.new()
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			control.min_value = spec.get("min", -1000000)
			control.max_value = spec.get("max", 1000000)
			control.step = spec.get("step", 1 if type == "int" else 0.01)
			control.value = value
			control.value_changed.connect(_numeric_changed.bind(id, key, type == "int"))
			return control
		"vector2", "vector3":
			var box := HBoxContainer.new()
			box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var count := 2 if type == "vector2" else 3
			for axis in count:
				var control := SpinBox.new()
				control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				control.min_value = -1000000
				control.max_value = 1000000
				control.step = 0.05
				control.value = value[axis]
				control.prefix = ["X ", "Y ", "Z "][axis]
				control.value_changed.connect(_vector_changed.bind(id, key, axis, count))
				box.add_child(control)
			return box
		"enum":
			var control := OptionButton.new()
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for item in spec.get("items", []): control.add_item(_localized_enum_item(item))
			control.select(int(value))
			control.item_selected.connect(_parameter_changed.bind(id, key))
			return control
		"color":
			var control := ColorPickerButton.new()
			control.color = value
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			control.color_changed.connect(_parameter_changed.bind(id, key))
			return control
		"path", "file", "node_path":
			var control := LineEdit.new()
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			control.text = _path_to_text(value) if type == "path" else String(value)
			control.text_submitted.connect(_text_changed.bind(id, key, type))
			control.focus_exited.connect(_line_focus_exited.bind(control, id, key, type))
			return control
	var fallback := Label.new()
	fallback.text = str(value)
	return fallback


func _localized_enum_item(item: String) -> String:
	return {
		"Global": "全局 Global", "Local": "局部 Local", "Instance": "实例 Instance",
		"Offset": "偏移 Offset", "Multiply": "乘算 Multiply", "Override": "覆盖 Override",
	}.get(item, item)


func _clear_graph() -> void:
	if _graph == null: return
	_graph.clear_connections()
	for child in _graph.get_children():
		if child is GraphNode:
			_graph.remove_child(child)
			child.queue_free()


func _find_entry(id: int) -> Dictionary:
	return config.find_node(id) if config != null else {}


func _input_type(entry: Dictionary, port: int) -> int:
	var type := StringName(entry.get("type", ""))
	if type == &"output": return ScatterSchema.REGION_PORT_TYPE if port == 0 else ScatterSchema.PLACEMENT_PORT_TYPE
	if ScatterSchema.is_region_operator(type): return ScatterSchema.REGION_PORT_TYPE
	if ScatterSchema.is_placement(type): return ScatterSchema.PLACEMENT_PORT_TYPE
	return 0


func _output_type(entry: Dictionary, _port: int) -> int:
	var type := StringName(entry.get("type", ""))
	if ScatterSchema.is_region(type): return ScatterSchema.REGION_PORT_TYPE
	if ScatterSchema.is_placement(type): return ScatterSchema.PLACEMENT_PORT_TYPE
	return 0


func _connection_requested(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if config == null: return
	var from_id := String(from_node).to_int()
	var to_id := String(to_node).to_int()
	var from_entry := _find_entry(from_id)
	var to_entry := _find_entry(to_id)
	if from_entry.is_empty() or to_entry.is_empty(): return
	var from_type := _output_type(from_entry, from_port)
	var to_type := _input_type(to_entry, to_port)
	if from_type == 0 or from_type != to_type:
		update_status("连接失败：Region 只能连接绿色端口，Placement 只能连接紫色端口。")
		return
	if config.would_create_cycle(from_id, to_id):
		update_status("连接失败：该连线会产生循环依赖。")
		return
	var old := config.incoming_connection(to_id, to_port)
	if not old.is_empty():
		_graph.disconnect_node(StringName(str(old.from_id)), int(old.from_port), to_node, to_port)
	config.connect_nodes(from_id, from_port, to_id, to_port)
	_graph.connect_node(from_node, from_port, to_node, to_port)
	_recipe_modified(false)


func _disconnection_requested(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if config == null: return
	config.disconnect_nodes(String(from_node).to_int(), from_port, String(to_node).to_int(), to_port)
	_graph.disconnect_node(from_node, from_port, to_node, to_port)
	_recipe_modified(false)


func _graph_node_selected(node: Node) -> void:
	if not node is GraphNode: return
	var entry := _find_entry(String(node.name).to_int())
	if entry.get("type", "") == "paint_region":
		_activate_paint_node(int(entry.id), false)


func _parameter_changed(value: Variant, id: int, key: String) -> void:
	var entry := _find_entry(id)
	if entry.is_empty(): return
	entry.params[key] = value
	_recipe_modified(false)


func _numeric_changed(value: float, id: int, key: String, as_int: bool) -> void:
	_parameter_changed(int(value) if as_int else value, id, key)


func _vector_changed(value: float, id: int, key: String, axis: int, count: int) -> void:
	var entry := _find_entry(id)
	if entry.is_empty(): return
	var vector = entry.params.get(key, Vector2.ZERO if count == 2 else Vector3.ZERO)
	vector[axis] = value
	entry.params[key] = vector
	_recipe_modified(false)


func _text_changed(value: String, id: int, key: String, type: String) -> void:
	var converted: Variant = value
	if type == "node_path": converted = NodePath(value)
	elif type == "path": converted = _text_to_path(value)
	_parameter_changed(converted, id, key)


func _line_focus_exited(control: LineEdit, id: int, key: String, type: String) -> void:
	_text_changed(control.text, id, key, type)


func _enabled_changed(value: bool, id: int) -> void:
	var entry := _find_entry(id)
	if entry.is_empty(): return
	entry.enabled = value
	_recipe_modified(false)


func _override_seed_changed(value: bool, id: int, control: SpinBox) -> void:
	var entry := _find_entry(id)
	if entry.is_empty(): return
	entry.override_seed = value
	control.visible = value
	_recipe_modified(false)


func _custom_seed_changed(value: float, id: int) -> void:
	var entry := _find_entry(id)
	if entry.is_empty(): return
	entry.custom_seed = int(value)
	_recipe_modified(false)


func _node_moved(id: int, graph_node: GraphNode) -> void:
	if _updating: return
	var entry := _find_entry(id)
	if entry.is_empty(): return
	entry.position = graph_node.position_offset
	config.emit_changed()
	recipe_changed.emit()


func _delete_node(id: int) -> void:
	if config == null: return
	var entry := _find_entry(id)
	if entry.get("type", "") == "output":
		update_status("Output 是配方的唯一出口，不能删除。")
		return
	if active_paint_node_id == id:
		_stop_painting()
		active_paint_node_id = 0
	config.remove_node(id)
	_recipe_modified(true)


func _show_add_popup(button: Button) -> void:
	var position := button.get_screen_position() + Vector2(0, button.size.y)
	_add_popup.position = Vector2i(position)
	_add_popup.popup()


func _on_add_type(id: int) -> void:
	if config == null: return
	var position := _graph.scroll_offset + _graph.size * 0.35
	var entry := config.add_node(_popup_types[id], position)
	if entry.get("type", "") == "paint_region": active_paint_node_id = int(entry.id)
	_recipe_modified(true)


func _on_seed_changed(value: float) -> void:
	if _updating or config == null: return
	config.seed = int(value)
	_recipe_modified(false)


func _on_reroll() -> void:
	if config == null: return
	config.seed = randi()
	_seed.value = config.seed
	_recipe_modified(false)
	build_requested.emit()


func _on_auto_rebuild_toggled(value: bool) -> void:
	if _updating or config == null: return
	config.auto_rebuild = value
	config.emit_changed()
	recipe_changed.emit()
	if value: build_requested.emit()


func _brush_radius_changed(value: float) -> void:
	brush_radius = value
	if paint_active: paint_mode_changed.emit(true)


func _collision_mask_changed(value: float) -> void:
	if _updating or config == null: return
	config.collision_mask = int(value)
	config.emit_changed()
	recipe_changed.emit()


func _activate_paint_node(id: int, start_painting: bool) -> void:
	var entry := _find_entry(id)
	if entry.get("type", "") != "paint_region": return
	active_paint_node_id = id
	_update_active_paint_ui()
	if start_painting:
		_paint_button.button_pressed = true


func get_active_paint_entry() -> Dictionary:
	var entry := _find_entry(active_paint_node_id)
	return entry if entry.get("type", "") == "paint_region" else {}


func _on_paint_toggled(value: bool) -> void:
	if value and get_active_paint_entry().is_empty():
		_paint_button.set_pressed_no_signal(false)
		update_status("请先选中或创建一个“绘制区域 Paint”节点。")
		return
	paint_active = value
	if value:
		_erase_button.set_pressed_no_signal(false)
		paint_erase = false
	paint_mode_changed.emit(paint_active)


func _on_erase_toggled(value: bool) -> void:
	if value and get_active_paint_entry().is_empty():
		_erase_button.set_pressed_no_signal(false)
		update_status("请先选中或创建一个“绘制区域 Paint”节点。")
		return
	paint_erase = value
	paint_active = value
	_paint_button.set_pressed_no_signal(value)
	paint_mode_changed.emit(paint_active)


func _stop_painting() -> void:
	paint_active = false
	paint_erase = false
	if _paint_button != null: _paint_button.set_pressed_no_signal(false)
	if _erase_button != null: _erase_button.set_pressed_no_signal(false)
	paint_mode_changed.emit(false)


func stop_painting() -> void:
	_stop_painting()


func _clear_active_paint() -> void:
	var entry := get_active_paint_entry()
	if entry.is_empty():
		update_status("没有活动的 Paint Region 图层。")
		return
	entry.params.strokes = []
	config.emit_changed()
	recipe_changed.emit()
	refresh_paint_count(active_paint_node_id)
	if config.auto_rebuild: build_requested.emit()


func refresh_paint_count(id: int) -> void:
	_update_paint_count(id)
	update_status()


func _update_paint_count(id: int) -> void:
	var label = _paint_count_labels.get(id)
	if not is_instance_valid(label): return
	var entry := _find_entry(id)
	var count := Array(entry.get("params", {}).get("strokes", [])).size()
	label.text = "%d 笔" % count


func _update_active_paint_ui() -> void:
	if _paint_layer_label == null: return
	var entry := get_active_paint_entry()
	if entry.is_empty():
		_paint_layer_label.text = "绘制图层：请选中 Paint Region 节点"
		_clear_paint_button.disabled = true
	else:
		_paint_layer_label.text = "绘制图层：%s（节点 #%d）" % [ScatterSchema.display_title(&"paint_region"), active_paint_node_id]
		_clear_paint_button.disabled = false


func _save_recipe() -> void:
	if config == null: return
	_save_dialog.current_file = "%s_scatter.tres" % String(target.name).to_snake_case()
	_save_dialog.popup_centered_ratio(0.65)


func _recipe_file_selected(path: String) -> void:
	var copy := config.duplicate_recipe()
	# Legacy directly painted instances remain scene-local. Paint Region strokes
	# are graph data and intentionally remain in reusable recipes.
	copy.manual_transforms.clear()
	copy.manual_colors.clear()
	copy.manual_custom_data.clear()
	var error := ResourceSaver.save(copy, path)
	update_status("配方已保存：%s" % path if error == OK else "保存失败（错误 %d）" % error)


func _load_recipe() -> void:
	if target == null: return
	_load_dialog.popup_centered_ratio(0.65)


func _load_recipe_file(path: String) -> void:
	var loaded = ResourceLoader.load(path, "ScatterConfig", ResourceLoader.CACHE_MODE_IGNORE)
	if not loaded is ScatterConfig:
		update_status("不是 Scatter 配方：%s" % path)
		return
	var copy: ScatterConfig = loaded.duplicate_recipe()
	copy.resource_local_to_scene = true
	copy.manual_transforms = config.manual_transforms.duplicate()
	copy.manual_colors = config.manual_colors.duplicate()
	copy.manual_custom_data = config.manual_custom_data.duplicate()
	copy.ensure_graph()
	target.set_meta(ScatterGenerator.META_KEY, copy)
	set_target(target)
	_recipe_modified(true)


func _recipe_modified(rebuild_visual: bool) -> void:
	if config == null: return
	config.emit_changed()
	recipe_changed.emit()
	if rebuild_visual: rebuild_graph()
	if config.auto_rebuild: build_requested.emit()


func update_status(message := "") -> void:
	if not message.is_empty():
		_status_label.text = message
		return
	if not is_instance_valid(target): return
	var count := target.multimesh.instance_count if target.multimesh != null else 0
	var paint_layers := 0
	var paint_strokes := 0
	for entry in config.nodes:
		if entry.get("type", "") == "paint_region":
			paint_layers += 1
			paint_strokes += Array(entry.get("params", {}).get("strokes", [])).size()
	_status_label.text = "%d 个实例 · %d 个绘制图层 / %d 笔 · 配方保存在当前 MultiMeshInstance3D" % [count, paint_layers, paint_strokes]
	if is_instance_valid(_output_stats_label):
		_output_stats_label.text = "当前输出：%d 个实例" % count


func _path_to_text(points: PackedVector3Array) -> String:
	var chunks: PackedStringArray = []
	for point in points: chunks.append("%g,%g,%g" % [point.x, point.y, point.z])
	return "; ".join(chunks)


func _text_to_path(text: String) -> PackedVector3Array:
	var points := PackedVector3Array()
	for chunk in text.split(";", false):
		var values := chunk.strip_edges().split(",", false)
		if values.size() == 3: points.append(Vector3(values[0].to_float(), values[1].to_float(), values[2].to_float()))
	return points
