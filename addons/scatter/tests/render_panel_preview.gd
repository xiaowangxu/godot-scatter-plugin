extends SceneTree


func _init() -> void:
	_render.call_deferred()


func _render() -> void:
	root.size = Vector2i(1920, 900)
	var background := ColorRect.new()
	background.color = Color("16191f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var target := MultiMeshInstance3D.new()
	target.name = "ForestScatter"
	target.multimesh = MultiMesh.new()
	target.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	target.multimesh.mesh = BoxMesh.new()
	root.add_child(target)

	var config := ScatterConfig.new()
	config.seed = 2026
	var box := config.add_node(&"shape_box", Vector2(80, 335))
	box.params.size = Vector3(16, 1, 12)
	var paint := config.add_node(&"paint_region", Vector2(80, 565))
	paint.params.strokes = [
		{"position": Vector3(-3, 0, 0), "normal": Vector3.UP, "radius": 2.0},
		{"position": Vector3(0, 0, 2), "normal": Vector3.UP, "radius": 2.5},
		{"position": Vector3(3, 0, 0), "normal": Vector3.UP, "radius": 2.0},
	]
	var random := config.add_node(&"create_random", Vector2(80, 55))
	random.params.amount = 80
	var rotation := config.add_node(&"random_rotation", Vector2(420, 55))
	var paint_random := config.add_node(&"create_random", Vector2(420, 555))
	paint_random.params.amount = 20
	var first_group := config.add_node(&"group", Vector2(790, 150))
	var second_group := config.add_node(&"group", Vector2(790, 520))
	var final_output := config.add_node(&"final_output", Vector2(1120, 300))
	config.connect_nodes(box.id, 0, first_group.id, 0)
	config.connect_nodes(random.id, 0, rotation.id, 0)
	config.connect_nodes(rotation.id, 0, first_group.id, 1)
	config.connect_nodes(paint.id, 0, second_group.id, 0)
	config.connect_nodes(paint_random.id, 0, second_group.id, 1)
	config.connect_nodes(first_group.id, 0, final_output.id, 0)
	config.connect_nodes(second_group.id, 0, final_output.id, 1)
	target.set_meta(ScatterGenerator.META_KEY, config)

	var panel := ScatterPanel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(panel)
	panel.set_target(target)
	panel.active_paint_node_id = int(paint.id)
	panel.rebuild_graph()
	var result := ScatterGenerator.build(target, config)
	ScatterGenerator.apply_to_multimesh(target, result)
	panel.update_group_counts(result)

	for i in 12: await process_frame
	RenderingServer.force_draw()
	await process_frame
	var image := root.get_texture().get_image()
	var path := "user://scatter_panel_preview.png"
	var error := image.save_png(path)
	print("Scatter panel preview: %s (error %d)" % [ProjectSettings.globalize_path(path), error])
	quit(0)
