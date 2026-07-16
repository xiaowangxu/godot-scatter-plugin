extends SceneTree


func _init() -> void:
	ScatterBuiltinRegistry.register_all()
	var ids := ScatterNodeRegistry.type_ids()
	assert(ids.size() == 37, "All built-in Scatter nodes must be registered")
	var seen: Dictionary[StringName, bool] = {}
	for prototype in ScatterNodeRegistry.prototypes():
		var type_id := prototype.get_type_id()
		assert(not seen.has(type_id), "Scatter node ids must be unique")
		seen[type_id] = true
		assert(ScatterExtensionRegistry.get_view_script(type_id) != null, "Every built-in node needs a view")
		assert(ScatterExtensionRegistry.create_editor_extension(type_id) != null, "Every built-in node needs an editor extension")
		for port in prototype.get_input_ports():
			assert(not port.id.is_empty())
		for port in prototype.get_output_ports():
			assert(not port.id.is_empty())
	var graph := ScatterGraphFactory.create_default()
	assert(graph.nodes.size() == 5)
	assert(graph.connections.size() == 4)
	assert(graph.final_output_node() != null)
	print("Scatter registry test passed")
	quit()
