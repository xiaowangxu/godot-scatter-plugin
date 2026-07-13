@tool
class_name ScatterInspector
extends EditorInspectorPlugin

signal open_requested(target: MultiMeshInstance3D)
signal rebuild_requested(target: MultiMeshInstance3D)
signal detach_requested(target: MultiMeshInstance3D)


func _can_handle(object: Object) -> bool:
	return object is MultiMeshInstance3D


func _parse_begin(object: Object) -> void:
	var target := object as MultiMeshInstance3D
	var panel := VBoxContainer.new()
	var header := HBoxContainer.new()
	var label := Label.new()
	label.text = "Scatter 散布配方"
	label.tooltip_text = "直接保存在此 MultiMeshInstance3D 上的 Region / Placement 数据流。"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var badge := Label.new()
	badge.text = "已就绪" if target.has_meta(ScatterGenerator.META_KEY) else "未配置"
	badge.tooltip_text = "已附加配方" if target.has_meta(ScatterGenerator.META_KEY) else "打开编辑器会创建入门配方"
	badge.modulate = Color("78c69a") if target.has_meta(ScatterGenerator.META_KEY) else Color("a5abb5")
	header.add_child(badge)
	panel.add_child(header)
	var row := HBoxContainer.new()
	var open := Button.new(); open.text = "打开 Scatter 编辑器"; open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open.tooltip_text = "在底部面板打开当前节点的 Region / Placement 图"
	open.pressed.connect(func(): open_requested.emit(target)); row.add_child(open)
	var rebuild := Button.new(); rebuild.text = "重新生成"; rebuild.disabled = not target.has_meta(ScatterGenerator.META_KEY)
	rebuild.tooltip_text = "合并最终输出连接的全部 Scatter Set，并重新生成 MultiMesh 实例数据"
	rebuild.pressed.connect(func(): rebuild_requested.emit(target)); row.add_child(rebuild)
	panel.add_child(row)
	if target.has_meta(ScatterGenerator.META_KEY):
		var detach := Button.new(); detach.text = "移除配方（保留实例）"; detach.flat = true
		detach.tooltip_text = "删除 Scatter 图配方，但保留当前 MultiMesh buffer 与实例"
		detach.pressed.connect(func(): detach_requested.emit(target)); panel.add_child(detach)
	add_custom_control(panel)
