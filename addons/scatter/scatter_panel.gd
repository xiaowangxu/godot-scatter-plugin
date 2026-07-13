@tool
class_name ScatterPanel
extends VBoxContainer

signal build_requested
signal recipe_changed
signal paint_mode_changed(active: bool)

enum NodeMenuAction {
	ADD,
	CUT,
	COPY,
	PASTE,
	DELETE,
	DUPLICATE,
	CLEAR_COPY_BUFFER,
	TOGGLE_ENABLED,
}

enum ConnectionMenuAction {
	DISCONNECT,
}

var target: MultiMeshInstance3D
var config: ScatterConfig
var paint_active := false
var paint_erase := false
var brush_radius := 2.0
var active_paint_node_id := 0
var history_action_active := false

var _title_label: Label
var _status_label: Label
var _paint_layer_label: Label
var _graph: GraphEdit
var _add_popup: PopupMenu
var _node_popup: PopupMenu
var _connection_popup: PopupMenu
var _popup_types: Dictionary = {}
var _undo_redo: EditorUndoRedoManager
var _copy_buffer: Dictionary = {}
var _clicked_connection: Dictionary = {}
var _menu_graph_position := Vector2.ZERO
var _menu_screen_position := Vector2.ZERO
var _pending_add_position := Vector2.INF
var _pending_node_moves: Dictionary = {}
var _node_move_commit_pending := false
var _seed: SpinBox
var _auto_rebuild: CheckBox
var _paint_button: Button
var _erase_button: Button
var _clear_paint_button: Button
var _paint_count_labels: Dictionary = {}
var _group_count_labels: Dictionary = {}
var _last_group_counts: Dictionary = {}
var _final_stats_label: Label
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
	_graph.add_valid_connection_type(ScatterSchema.SCATTER_SET_PORT_TYPE, ScatterSchema.SCATTER_SET_PORT_TYPE)
	_graph.connection_request.connect(_connection_requested)
	_graph.disconnection_request.connect(_disconnection_requested)
	_graph.node_selected.connect(_graph_node_selected)
	_graph.delete_nodes_request.connect(_delete_nodes_requested)
	_graph.copy_nodes_request.connect(_copy_selected_nodes.bind(false))
	_graph.cut_nodes_request.connect(_copy_selected_nodes.bind(true))
	_graph.paste_nodes_request.connect(_paste_nodes_requested)
	_graph.duplicate_nodes_request.connect(_duplicate_selected_nodes)
	_graph.popup_request.connect(_show_graph_context_menu)
	add_child(_graph)
	_build_graph_context_menus()

	_status_label = Label.new()
	_status_label.text = "请选择一个 MultiMeshInstance3D 开始编辑。"
	_status_label.tooltip_text = "配方保存在原生 MultiMeshInstance3D 的元数据中，不会创建额外场景节点。"
	add_child(_status_label)


func set_undo_redo(value: EditorUndoRedoManager) -> void:
	_undo_redo = value


func _build_graph_context_menus() -> void:
	_node_popup = PopupMenu.new()
	_node_popup.name = "NodeOperationsMenu"
	_node_popup.add_item("添加节点", NodeMenuAction.ADD)
	_node_popup.add_separator()
	_add_graph_shortcut_item("剪切", NodeMenuAction.CUT, &"ui_cut")
	_add_graph_shortcut_item("复制", NodeMenuAction.COPY, &"ui_copy")
	_add_graph_shortcut_item("粘贴", NodeMenuAction.PASTE, &"ui_paste")
	_add_graph_shortcut_item("删除", NodeMenuAction.DELETE, &"ui_graph_delete")
	_add_graph_shortcut_item("创建副本", NodeMenuAction.DUPLICATE, &"ui_graph_duplicate")
	_node_popup.add_item("清空复制缓冲区", NodeMenuAction.CLEAR_COPY_BUFFER)
	_node_popup.add_separator()
	_node_popup.add_item("停用节点", NodeMenuAction.TOGGLE_ENABLED)
	_node_popup.id_pressed.connect(_node_menu_id_pressed)
	add_child(_node_popup)

	_connection_popup = PopupMenu.new()
	_connection_popup.name = "ConnectionOperationsMenu"
	_connection_popup.add_item("断开连接", ConnectionMenuAction.DISCONNECT)
	_connection_popup.id_pressed.connect(_connection_menu_id_pressed)
	add_child(_connection_popup)


func _add_graph_shortcut_item(label: String, id: int, action: StringName) -> void:
	var shortcut := Shortcut.new()
	shortcut.resource_name = label
	shortcut.events = InputMap.action_get_events(action)
	_node_popup.add_shortcut(shortcut, id)


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
	generate.tooltip_text = "求值所有连接到最终输出的 Scatter Set，并重建 MultiMesh 实例数据"
	generate.pressed.connect(func(): build_requested.emit())
	top.add_child(generate)

	var focus := Button.new()
	focus.text = "定位输出"
	focus.tooltip_text = "把图视图移动到最终输出节点"
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
	if target != value:
		_last_group_counts.clear()
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
	var groups := config.group_nodes()
	if not groups.is_empty(): groups[0].position = Vector2(1110, 190)
	var final_output := config.final_output_node()
	if not final_output.is_empty(): final_output.position = Vector2(1420, 210)
	config.emit_changed()


func rebuild_graph(focus_view := true) -> void:
	if not is_node_ready(): return
	_updating = true
	_clear_graph()
	_paint_count_labels.clear()
	_group_count_labels.clear()
	_final_stats_label = null
	if config == null:
		_updating = false
		return
	config.ensure_graph()
	for entry in config.nodes:
		var graph_node := _make_graph_node(entry)
		_graph.add_child(graph_node)
		_tint_native_titlebar(graph_node, ScatterSchema.definition(entry.get("type", "")).get("color", Color.GRAY))
	for connection in config.connections:
		var from_name := StringName(str(connection.get("from_id", 0)))
		var to_name := StringName(str(connection.get("to_id", 0)))
		if _graph.has_node(NodePath(String(from_name))) and _graph.has_node(NodePath(String(to_name))):
			_graph.connect_node(from_name, int(connection.get("from_port", 0)), to_name, int(connection.get("to_port", 0)))
	_updating = false
	_update_active_paint_ui()
	update_status()
	if focus_view:
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


func _tint_native_titlebar(node: GraphNode, color: Color) -> void:
	# Keep Godot's GraphNode geometry, padding, borders and selection behavior.
	# Visual Shader nodes tint this native titlebar to identify node families.
	var normal := node.get_theme_stylebox("titlebar")
	if normal is StyleBoxFlat:
		var tinted := normal.duplicate() as StyleBoxFlat
		tinted.bg_color = color.darkened(0.38)
		node.add_theme_stylebox_override("titlebar", tinted)
	var selected := node.get_theme_stylebox("titlebar_selected")
	if selected is StyleBoxFlat:
		var tinted_selected := selected.duplicate() as StyleBoxFlat
		tinted_selected.bg_color = color.darkened(0.27)
		node.add_theme_stylebox_override("titlebar_selected", tinted_selected)


func _make_graph_node(entry: Dictionary) -> GraphNode:
	var id := int(entry.get("id", 0))
	var type := StringName(entry.get("type", ""))
	var definition := ScatterSchema.definition(type)
	var node := GraphNode.new()
	node.name = str(id)
	node.title = ScatterSchema.display_title(type)
	node.tooltip_text = ScatterSchema.description(type)
	node.position_offset = entry.get("position", Vector2.ZERO)
	if ScatterSchema.is_final_output(type):
		node.custom_minimum_size.x = 200
	elif ScatterSchema.is_group(type):
		node.custom_minimum_size.x = 225
	else:
		node.custom_minimum_size.x = 270
	node.dragged.connect(_node_dragged.bind(id))
	node.delete_request.connect(_delete_node.bind(id))

	if ScatterSchema.is_final_output(type):
		_add_final_output_rows(node)
		return node

	var titlebar_controls := node.get_titlebar_hbox()
	var enabled := CheckBox.new()
	enabled.button_pressed = entry.get("enabled", true)
	enabled.tooltip_text = "启用 / 停用节点"
	enabled.toggled.connect(_enabled_changed.bind(id))
	titlebar_controls.add_child(enabled)

	if ScatterSchema.is_group(type):
		_add_group_rows(node, id)
		return node
	if ScatterSchema.is_region_source(type):
		_add_region_source_rows(node, entry)
	elif ScatterSchema.is_region_operator(type):
		_add_binary_rows(node, ScatterSchema.REGION_PORT_TYPE, ScatterSchema.REGION_COLOR, "A", "B", "区域")
	elif type == &"placement_merge":
		_add_binary_rows(node, ScatterSchema.PLACEMENT_PORT_TYPE, ScatterSchema.PLACEMENT_COLOR, "A", "B", "实例流")
	elif ScatterSchema.is_placement_source(type):
		_add_placement_source_row(node)
	else:
		_add_flow_row(node, ScatterSchema.PLACEMENT_PORT_TYPE, ScatterSchema.PLACEMENT_COLOR, "实例流")

	if ScatterSchema.uses_seed(type):
		_add_seed_row(node, entry)
	_add_parameter_rows(node, entry, definition)
	return node


func _add_group_rows(node: GraphNode, id: int) -> void:
	var output_label := Label.new()
	output_label.text = "散布"
	output_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	node.add_child(output_label)
	node.set_slot(node.get_child_count() - 1, false, 0, Color.WHITE, true, ScatterSchema.SCATTER_SET_PORT_TYPE, ScatterSchema.SCATTER_SET_COLOR)
	var region_row := Label.new()
	region_row.text = "区域"
	region_row.tooltip_text = "这个 Scatter Set 使用的区域"
	node.add_child(region_row)
	node.set_slot(node.get_child_count() - 1, true, ScatterSchema.REGION_PORT_TYPE, ScatterSchema.REGION_COLOR, false, 0, Color.WHITE)
	var placement_row := Label.new()
	placement_row.text = "布点"
	placement_row.tooltip_text = "生成和处理实例的布点流"
	node.add_child(placement_row)
	node.set_slot(node.get_child_count() - 1, true, ScatterSchema.PLACEMENT_PORT_TYPE, ScatterSchema.PLACEMENT_COLOR, false, 0, Color.WHITE)
	
	var count := Label.new()
	count.text = str(_last_group_counts.get(id, "—"))
	count.modulate = Color("d8b36f")
	count.tooltip_text = "此 Scatter Set 的实例数量"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_group_count_labels[id] = count
	node.add_child(count)

func _add_final_output_rows(node: GraphNode) -> void:
	for port in config.final_input_count():
		var row := Label.new()
		row.text = "集合 %d" % (port + 1)
		row.tooltip_text = "连接一个散布组输出的 Scatter Set"
		node.add_child(row)
		node.set_slot(node.get_child_count() - 1, true, ScatterSchema.SCATTER_SET_PORT_TYPE, ScatterSchema.SCATTER_SET_COLOR, false, 0, Color.WHITE)
	_final_stats_label = Label.new()
	_final_stats_label.text = "%d 个实例" % (target.multimesh.instance_count if is_instance_valid(target) and target.multimesh != null else 0)
	_final_stats_label.modulate = Color("d8b36f")
	_final_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_final_stats_label.tooltip_text = "写入当前 MultiMesh 的实例总数"
	node.add_child(_final_stats_label)


func _add_region_source_rows(node: GraphNode, entry: Dictionary) -> void:
	var id := int(entry.get("id", 0))
	if entry.get("type", "") == "paint_region":
		var paint_actions := HBoxContainer.new()
		var activate := Button.new()
		activate.text = "绘制"
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
	output_row.text = "区域"
	output_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	output_row.tooltip_text = "连接到区域运算节点或散布组"
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


func _add_placement_source_row(node: GraphNode) -> void:
	var row := Label.new()
	row.text = "实例流"
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.tooltip_text = "输出新生成的实例；需要组合多条实例流时使用“合并布点”节点。"
	node.add_child(row)
	node.set_slot(node.get_child_count() - 1, false, 0, Color.WHITE, true, ScatterSchema.PLACEMENT_PORT_TYPE, ScatterSchema.PLACEMENT_COLOR)


func _add_flow_row(node: GraphNode, port_type: int, color: Color, text: String) -> void:
	var row := Label.new()
	row.text = text
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.tooltip_text = "左侧接收上游实例，右侧输出处理后的实例。"
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
		label.custom_minimum_size.x = 78
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
	if ScatterSchema.is_group(type): return ScatterSchema.REGION_PORT_TYPE if port == 0 else ScatterSchema.PLACEMENT_PORT_TYPE
	if ScatterSchema.is_final_output(type): return ScatterSchema.SCATTER_SET_PORT_TYPE
	if ScatterSchema.is_region_operator(type): return ScatterSchema.REGION_PORT_TYPE
	if ScatterSchema.is_placement_source(type): return 0
	if ScatterSchema.is_placement(type): return ScatterSchema.PLACEMENT_PORT_TYPE
	return 0


func _output_type(entry: Dictionary, _port: int) -> int:
	var type := StringName(entry.get("type", ""))
	if ScatterSchema.is_group(type): return ScatterSchema.SCATTER_SET_PORT_TYPE
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
		if ScatterSchema.is_placement_source(to_entry.get("type", "")):
			update_status("生成节点没有输入；请使用“合并布点”组合多条实例流。")
			return
		update_status("连接失败：区域、布点与 Scatter Set 必须连接同色端口。")
		return
	if config.would_create_cycle(from_id, to_id):
		update_status("连接失败：该连线会产生循环依赖。")
		return
	var selected := _selected_node_ids(false)
	var before := _make_graph_state(config, selected, active_paint_node_id)
	var working := config.duplicate_recipe()
	working.connect_nodes(from_id, from_port, to_id, to_port)
	var after := _make_graph_state(working, selected, active_paint_node_id)
	_commit_graph_action("连接 Scatter 节点", before, after)


func _disconnection_requested(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if config == null: return
	var from_id := String(from_node).to_int()
	var to_id := String(to_node).to_int()
	var exists := false
	for connection in config.connections:
		if (int(connection.get("from_id", 0)) == from_id
				and int(connection.get("from_port", 0)) == from_port
				and int(connection.get("to_id", 0)) == to_id
				and int(connection.get("to_port", 0)) == to_port):
			exists = true
			break
	if not exists: return
	var selected := _selected_node_ids(false)
	var before := _make_graph_state(config, selected, active_paint_node_id)
	var working := config.duplicate_recipe()
	working.disconnect_nodes(from_id, from_port, to_id, to_port)
	working.ensure_graph()
	var after := _make_graph_state(working, selected, active_paint_node_id)
	_commit_graph_action("断开 Scatter 节点", before, after)


func _graph_node_selected(node: Node) -> void:
	if not node is GraphNode: return
	var entry := _find_entry(String(node.name).to_int())
	if entry.get("type", "") == "paint_region":
		_activate_paint_node(int(entry.id), false)


func _parameter_changed(value: Variant, id: int, key: String) -> void:
	var merge_mode := UndoRedo.MERGE_ENDS if value is Color else UndoRedo.MERGE_DISABLE
	_commit_node_parameter(id, key, value, "", merge_mode)


func _numeric_changed(value: float, id: int, key: String, as_int: bool) -> void:
	_commit_node_parameter(id, key, int(value) if as_int else value, "", UndoRedo.MERGE_ENDS)


func _vector_changed(value: float, id: int, key: String, axis: int, count: int) -> void:
	var entry := _find_entry(id)
	if entry.is_empty(): return
	var vector = entry.params.get(key, Vector2.ZERO if count == 2 else Vector3.ZERO)
	vector[axis] = value
	_commit_node_parameter(id, key, vector, ["X", "Y", "Z"][axis], UndoRedo.MERGE_ENDS)


func _text_changed(value: String, id: int, key: String, type: String) -> void:
	var converted: Variant = value
	if type == "node_path": converted = NodePath(value)
	elif type == "path": converted = _text_to_path(value)
	_commit_node_parameter(id, key, converted, "", UndoRedo.MERGE_DISABLE)


func _line_focus_exited(control: LineEdit, id: int, key: String, type: String) -> void:
	_text_changed(control.text, id, key, type)


func _enabled_changed(value: bool, id: int) -> void:
	if _updating or config == null: return
	var entry := _find_entry(id)
	if entry.is_empty() or bool(entry.get("enabled", true)) == value: return
	var selected := _selected_node_ids(false)
	var before := _make_graph_state(config, selected, active_paint_node_id)
	var working := config.duplicate_recipe()
	working.find_node(id).enabled = value
	var after := _make_graph_state(working, selected, active_paint_node_id)
	_commit_graph_action("启用 Scatter 节点" if value else "停用 Scatter 节点", before, after)


func _override_seed_changed(value: bool, id: int, control: SpinBox) -> void:
	control.visible = value
	_commit_node_entry_value(id, "override_seed", value, "使用独立种子", "", UndoRedo.MERGE_DISABLE)


func _custom_seed_changed(value: float, id: int) -> void:
	_commit_node_entry_value(id, "custom_seed", int(value), "独立种子", "", UndoRedo.MERGE_ENDS)


func _commit_node_parameter(id: int, key: String, value: Variant, component: String, merge_mode: int) -> void:
	var entry := _find_entry(id)
	if _updating or entry.is_empty(): return
	var old_value: Variant = entry.get("params", {}).get(key)
	if old_value == value: return
	var before := _make_graph_state(config, _selected_node_ids(false), active_paint_node_id)
	entry.params[key] = value
	_notify_managed_recipe_change()
	var after := _make_graph_state(config, _selected_node_ids(false), active_paint_node_id)
	var label := ScatterSchema.parameter_label(key)
	_commit_graph_action(_node_value_action_name(entry, id, label, component), before, after, merge_mode, false)


func _commit_node_entry_value(id: int, field: String, value: Variant, label: String, component: String, merge_mode: int) -> void:
	var entry := _find_entry(id)
	if _updating or entry.is_empty(): return
	if entry.get(field) == value: return
	var before := _make_graph_state(config, _selected_node_ids(false), active_paint_node_id)
	entry[field] = value
	_notify_managed_recipe_change()
	var after := _make_graph_state(config, _selected_node_ids(false), active_paint_node_id)
	_commit_graph_action(_node_value_action_name(entry, id, label, component), before, after, merge_mode, false)


func _node_value_action_name(entry: Dictionary, id: int, label: String, component: String) -> String:
	var node_title := ScatterSchema.display_title(entry.get("type", ""))
	var field_name := "%s %s" % [label, component] if not component.is_empty() else label
	# Node id and field/axis make MERGE_ENDS local to exactly one editor control.
	return "修改 %s #%d · %s" % [node_title, id, field_name]


func _notify_managed_recipe_change() -> void:
	history_action_active = true
	_recipe_modified(false)
	history_action_active = false


func _node_dragged(from: Vector2, to: Vector2, id: int) -> void:
	if _updating or from.is_equal_approx(to): return
	_pending_node_moves[id] = {"from": from, "to": to}
	if not _node_move_commit_pending:
		_node_move_commit_pending = true
		_commit_node_moves.call_deferred()


func _commit_node_moves() -> void:
	_node_move_commit_pending = false
	if config == null or _pending_node_moves.is_empty(): return
	var moves := _pending_node_moves.duplicate(true)
	_pending_node_moves.clear()
	var selected := _selected_node_ids(false)
	var before := _make_graph_state(config, selected, active_paint_node_id)
	var working := config.duplicate_recipe()
	for id in moves:
		var entry := working.find_node(int(id))
		if not entry.is_empty(): entry.position = moves[id].to
	var after := _make_graph_state(working, selected, active_paint_node_id)
	_commit_graph_action("移动 Scatter 节点", before, after)


func _delete_node(id: int) -> void:
	_delete_node_ids([id], "删除 Scatter 节点")


func _show_add_popup(button: Button) -> void:
	_pending_add_position = Vector2.INF
	var position := button.get_screen_position() + Vector2(0, button.size.y)
	_add_popup.position = Vector2i(position)
	_add_popup.popup()


func _on_add_type(id: int) -> void:
	if config == null: return
	var position := _pending_add_position
	if position == Vector2.INF:
		position = _graph_position_from_local(_graph.size * 0.5)
	_pending_add_position = Vector2.INF
	var before := _make_graph_state(config, _selected_node_ids(false), active_paint_node_id)
	var working := config.duplicate_recipe()
	var entry := working.add_node(_popup_types[id], position)
	var next_active := active_paint_node_id
	if entry.get("type", "") == "paint_region": next_active = int(entry.id)
	if ScatterSchema.is_group(entry.get("type", "")):
		var final_output := working.final_output_node()
		if not final_output.is_empty():
			var port := 0
			while not working.incoming_connection(int(final_output.id), port).is_empty(): port += 1
			working.connect_nodes(int(entry.id), 0, int(final_output.id), port)
	working.ensure_graph()
	var selected: Array[int] = [int(entry.id)]
	var after := _make_graph_state(working, selected, next_active)
	_commit_graph_action("添加 Scatter 节点", before, after)


func _show_graph_context_menu(at_position: Vector2) -> void:
	if config == null: return
	_menu_graph_position = _graph_position_from_local(at_position)
	_menu_screen_position = _graph.get_screen_position() + at_position
	_clicked_connection = _graph.get_closest_connection_at_point(at_position, 8.0)
	if not _clicked_connection.is_empty():
		_connection_popup.position = Vector2i(_menu_screen_position)
		_connection_popup.reset_size()
		_connection_popup.popup()
		return

	var clicked_node := _graph_node_at(at_position)
	if clicked_node != null and not clicked_node.selected:
		for child in _graph.get_children():
			if child is GraphNode: child.selected = false
		clicked_node.selected = true
	_configure_node_context_menu()
	_node_popup.position = Vector2i(_menu_screen_position)
	_node_popup.reset_size()
	_node_popup.popup()


func _graph_node_at(local_position: Vector2) -> GraphNode:
	for index in range(_graph.get_child_count() - 1, -1, -1):
		var child := _graph.get_child(index)
		if child is GraphNode and child.visible and child.get_rect().has_point(local_position):
			return child
	return null


func _configure_node_context_menu() -> void:
	var selected := _selected_node_ids(true)
	var has_selection := not selected.is_empty()
	var has_copy := not Array(_copy_buffer.get("nodes", [])).is_empty()
	_set_node_menu_disabled(NodeMenuAction.CUT, not has_selection)
	_set_node_menu_disabled(NodeMenuAction.COPY, not has_selection)
	_set_node_menu_disabled(NodeMenuAction.PASTE, not has_copy)
	_set_node_menu_disabled(NodeMenuAction.DELETE, not has_selection)
	_set_node_menu_disabled(NodeMenuAction.DUPLICATE, not has_selection)
	_set_node_menu_disabled(NodeMenuAction.CLEAR_COPY_BUFFER, not has_copy)
	_set_node_menu_disabled(NodeMenuAction.TOGGLE_ENABLED, not has_selection)
	var all_enabled := true
	for id in selected:
		if not bool(_find_entry(id).get("enabled", true)):
			all_enabled = false
			break
	var toggle_index := _node_popup.get_item_index(NodeMenuAction.TOGGLE_ENABLED)
	_node_popup.set_item_text(toggle_index, "停用节点" if all_enabled else "启用节点")


func _set_node_menu_disabled(id: int, disabled: bool) -> void:
	var index := _node_popup.get_item_index(id)
	if index >= 0: _node_popup.set_item_disabled(index, disabled)


func _node_menu_id_pressed(id: int) -> void:
	match id:
		NodeMenuAction.ADD:
			_pending_add_position = _menu_graph_position
			_add_popup.position = Vector2i(_menu_screen_position)
			_add_popup.popup()
		NodeMenuAction.CUT:
			_copy_selected_nodes(true)
		NodeMenuAction.COPY:
			_copy_selected_nodes(false)
		NodeMenuAction.PASTE:
			_paste_snapshot(_copy_buffer, _menu_graph_position, "粘贴 Scatter 节点")
		NodeMenuAction.DELETE:
			_delete_node_ids(_selected_node_ids(true), "删除 Scatter 节点")
		NodeMenuAction.DUPLICATE:
			_duplicate_selected_nodes()
		NodeMenuAction.CLEAR_COPY_BUFFER:
			_copy_buffer.clear()
		NodeMenuAction.TOGGLE_ENABLED:
			_toggle_selected_nodes()


func _connection_menu_id_pressed(id: int) -> void:
	if id != ConnectionMenuAction.DISCONNECT or _clicked_connection.is_empty(): return
	_disconnection_requested(
		_clicked_connection.get("from_node", StringName()),
		int(_clicked_connection.get("from_port", 0)),
		_clicked_connection.get("to_node", StringName()),
		int(_clicked_connection.get("to_port", 0)),
	)
	_clicked_connection.clear()


func _selected_node_ids(deletable_only := true) -> Array[int]:
	var result: Array[int] = []
	if _graph == null: return result
	for child in _graph.get_children():
		if not child is GraphNode or not child.selected: continue
		var id := String(child.name).to_int()
		var entry := _find_entry(id)
		if entry.is_empty(): continue
		if deletable_only and ScatterSchema.is_final_output(entry.get("type", "")): continue
		result.append(id)
	return result


func _delete_nodes_requested(nodes: Array) -> void:
	var ids: Array[int] = []
	for node_name in nodes:
		ids.append(String(node_name).to_int())
	if ids.is_empty(): ids = _selected_node_ids(true)
	_delete_node_ids(ids, "删除 Scatter 节点")


func _delete_node_ids(ids: Array, action_name: String) -> void:
	if config == null: return
	var deletable: Array[int] = []
	for value in ids:
		var id := int(value)
		var entry := _find_entry(id)
		if entry.is_empty(): continue
		if ScatterSchema.is_final_output(entry.get("type", "")):
			update_status("最终输出是配方的唯一出口，不能删除。")
			continue
		if not deletable.has(id): deletable.append(id)
	if deletable.is_empty(): return
	var before := _make_graph_state(config, _selected_node_ids(false), active_paint_node_id)
	var working := config.duplicate_recipe()
	for id in deletable: working.remove_node(id)
	working.ensure_graph()
	var next_selection := _selected_node_ids(false)
	for id in deletable: next_selection.erase(id)
	var next_active := 0 if deletable.has(active_paint_node_id) else active_paint_node_id
	var after := _make_graph_state(working, next_selection, next_active)
	_commit_graph_action(action_name, before, after)


func _copy_selected_nodes(cut := false) -> void:
	var snapshot := _selected_nodes_snapshot()
	if snapshot.is_empty(): return
	_copy_buffer = snapshot.duplicate(true)
	if cut:
		_delete_node_ids(snapshot.get("ids", []), "剪切 Scatter 节点")
	else:
		update_status("已复制 %d 个 Scatter 节点。" % Array(snapshot.nodes).size())


func _selected_nodes_snapshot() -> Dictionary:
	if config == null: return {}
	var ids := _selected_node_ids(true)
	if ids.is_empty(): return {}
	var id_set := {}
	var copied_nodes: Array[Dictionary] = []
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for id in ids:
		id_set[id] = true
		var entry := _find_entry(id).duplicate(true)
		copied_nodes.append(entry)
		var position: Vector2 = entry.get("position", Vector2.ZERO)
		minimum = minimum.min(position)
		maximum = maximum.max(position)
	var copied_connections: Array[Dictionary] = []
	for connection in config.connections:
		if id_set.has(int(connection.get("from_id", 0))) and id_set.has(int(connection.get("to_id", 0))):
			copied_connections.append(connection.duplicate(true))
	return {
		"ids": ids.duplicate(),
		"nodes": copied_nodes,
		"connections": copied_connections,
		"center": (minimum + maximum) * 0.5,
	}


func _paste_nodes_requested() -> void:
	var mouse_position := _graph.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, _graph.size).has_point(mouse_position):
		mouse_position = _graph.size * 0.5
	_paste_snapshot(_copy_buffer, _graph_position_from_local(mouse_position), "粘贴 Scatter 节点")


func _duplicate_selected_nodes() -> void:
	var snapshot := _selected_nodes_snapshot()
	if snapshot.is_empty(): return
	var center: Vector2 = snapshot.get("center", Vector2.ZERO)
	_paste_snapshot(snapshot, center + Vector2(24, 24), "创建 Scatter 节点副本")


func _paste_snapshot(snapshot: Dictionary, target_position: Vector2, action_name: String) -> void:
	if config == null or Array(snapshot.get("nodes", [])).is_empty(): return
	var before := _make_graph_state(config, _selected_node_ids(false), active_paint_node_id)
	var working := config.duplicate_recipe()
	var offset := target_position - Vector2(snapshot.get("center", Vector2.ZERO))
	var remap := {}
	var new_ids: Array[int] = []
	var new_group_ids: Array[int] = []
	var next_active := active_paint_node_id
	for source_entry in snapshot.get("nodes", []):
		var entry: Dictionary = source_entry.duplicate(true)
		var old_id := int(entry.get("id", 0))
		var new_id := working.allocate_id()
		entry.id = new_id
		entry.position = Vector2(entry.get("position", Vector2.ZERO)) + offset
		working.nodes.append(entry)
		remap[old_id] = new_id
		new_ids.append(new_id)
		if entry.get("type", "") == "group": new_group_ids.append(new_id)
		if entry.get("type", "") == "paint_region" and next_active == 0: next_active = new_id
	for source_connection in snapshot.get("connections", []):
		var from_id := int(source_connection.get("from_id", 0))
		var to_id := int(source_connection.get("to_id", 0))
		if not remap.has(from_id) or not remap.has(to_id): continue
		working.connect_nodes(
			int(remap[from_id]), int(source_connection.get("from_port", 0)),
			int(remap[to_id]), int(source_connection.get("to_port", 0)),
		)
	var final_output := working.final_output_node()
	for group_id in new_group_ids:
		if final_output.is_empty(): break
		var port := 0
		while not working.incoming_connection(int(final_output.id), port).is_empty(): port += 1
		working.connect_nodes(group_id, 0, int(final_output.id), port)
	working.ensure_graph()
	var after := _make_graph_state(working, new_ids, next_active)
	_commit_graph_action(action_name, before, after)


func _toggle_selected_nodes() -> void:
	var ids := _selected_node_ids(true)
	if ids.is_empty() or config == null: return
	var enable := false
	for id in ids:
		if not bool(_find_entry(id).get("enabled", true)):
			enable = true
			break
	var before := _make_graph_state(config, _selected_node_ids(false), active_paint_node_id)
	var working := config.duplicate_recipe()
	for id in ids: working.find_node(id).enabled = enable
	var after := _make_graph_state(working, _selected_node_ids(false), active_paint_node_id)
	_commit_graph_action("启用 Scatter 节点" if enable else "停用 Scatter 节点", before, after)


func _graph_position_from_local(local_position: Vector2) -> Vector2:
	return (_graph.scroll_offset + local_position) / maxf(_graph.zoom, 0.001)


func _make_graph_state(recipe: ScatterConfig, selected_ids: Array[int], paint_node_id: int) -> Dictionary:
	return {
		"nodes": recipe.nodes.duplicate(true),
		"connections": recipe.connections.duplicate(true),
		"next_id": recipe.next_id,
		"selected_ids": selected_ids.duplicate(),
		"active_paint_node_id": paint_node_id,
		"scroll_offset": _graph.scroll_offset if _graph != null else Vector2.ZERO,
		"zoom": _graph.zoom if _graph != null else 1.0,
	}


func _commit_graph_action(
		action_name: String,
		before: Dictionary,
		after: Dictionary,
		merge_mode := UndoRedo.MERGE_DISABLE,
		execute := true,
) -> void:
	if config == null: return
	var recipe := config
	if _undo_redo == null:
		if execute: _restore_graph_state(recipe, after)
		return
	var history_context: Object = target if is_instance_valid(target) else recipe
	_undo_redo.create_action(action_name, merge_mode, history_context)
	_undo_redo.add_do_method(self, "_restore_graph_state", recipe, after.duplicate(true))
	_undo_redo.add_undo_method(self, "_restore_graph_state", recipe, before.duplicate(true))
	_undo_redo.commit_action(execute)


func _restore_graph_state(recipe: ScatterConfig, state: Dictionary) -> void:
	var is_current_recipe := config == recipe
	if is_current_recipe: history_action_active = true
	var restored_nodes: Array = state.get("nodes", []).duplicate(true)
	var restored_connections: Array = state.get("connections", []).duplicate(true)
	recipe.nodes.assign(restored_nodes)
	recipe.connections.assign(restored_connections)
	recipe.next_id = int(state.get("next_id", recipe.next_id))
	recipe.emit_changed()
	if not is_current_recipe: return
	var next_active := int(state.get("active_paint_node_id", 0))
	if next_active != 0 and recipe.find_node(next_active).get("type", "") != "paint_region":
		next_active = 0
	if paint_active and next_active == 0: _stop_painting()
	active_paint_node_id = next_active
	rebuild_graph(false)
	_restore_graph_view.call_deferred(recipe, state.duplicate(true))
	recipe_changed.emit()
	if recipe.auto_rebuild: build_requested.emit()
	history_action_active = false


func _restore_graph_view(recipe: ScatterConfig, state: Dictionary) -> void:
	if config != recipe or _graph == null: return
	_graph.zoom = float(state.get("zoom", _graph.zoom))
	_graph.scroll_offset = Vector2(state.get("scroll_offset", _graph.scroll_offset))
	for child in _graph.get_children():
		if child is GraphNode: child.selected = false
	for value in state.get("selected_ids", []):
		var node := _graph.get_node_or_null(NodePath(str(int(value)))) as GraphNode
		if node != null: node.selected = true


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


func update_group_counts(result: Dictionary) -> void:
	_last_group_counts = Dictionary(result.get("group_counts", {})).duplicate()
	for id in _group_count_labels:
		var label = _group_count_labels[id]
		if is_instance_valid(label): label.text = str(_last_group_counts.get(id, 0))
	update_status()


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
	var group_count := config.group_nodes().size()
	_status_label.text = "%d 个实例 · %d 个散布组 · %d 个绘制图层 / %d 笔 · 配方保存在当前 MultiMeshInstance3D" % [count, group_count, paint_layers, paint_strokes]
	if is_instance_valid(_final_stats_label):
		_final_stats_label.text = "%d 个实例" % count


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
