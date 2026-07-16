extends SceneTree

const CHAIN_SIZE := 2_000
const INSTANCE_COUNT := 100_000


func _init() -> void:
	ScatterBuiltinRegistry.register_all()
	var graph := _large_chain(CHAIN_SIZE)
	var started := Time.get_ticks_usec()
	var plan := ScatterGraphCompiler.compile(graph)
	var compile_usec := Time.get_ticks_usec() - started
	assert(not plan.has_errors())
	assert(plan.ordered_node_ids.size() == CHAIN_SIZE + 2)

	var instances := ScatterInstances.new()
	instances.transforms.resize(INSTANCE_COUNT)
	instances.colors.resize(INSTANCE_COUNT)
	instances.custom_data.resize(INSTANCE_COUNT)
	for index in INSTANCE_COUNT:
		instances.transforms[index] = Transform3D(Basis(), Vector3(float(index % 200) - 100.0, 0, 0))
		instances.colors[index] = Color.WHITE
		instances.custom_data[index] = Color.TRANSPARENT
	started = Time.get_ticks_usec()
	ScatterFilterOps.remove_outside(instances, ScatterBoxRegion.new(Vector3.ZERO, Vector3(100, 2, 2)))
	var filter_usec := Time.get_ticks_usec() - started

	print("Compile %d nodes: %.2f ms" % [CHAIN_SIZE + 2, compile_usec / 1000.0])
	print("Filter %d instances to %d: %.2f ms" % [INSTANCE_COUNT, instances.transforms.size(), filter_usec / 1000.0])
	quit()


func _large_chain(transform_count: int) -> ScatterGraph:
	var graph := ScatterGraph.new()
	var source := ScatterSingleNode.new()
	source.node_id = 1
	graph.nodes.append(source)
	var previous: ScatterNode = source
	for index in transform_count:
		var node := ScatterTransformNode.new()
		node.node_id = index + 2
		graph.nodes.append(node)
		graph.connections.append(ScatterConnection.create(previous.node_id, &"instances", node.node_id, &"instances"))
		previous = node
	var output := ScatterFinalOutputNode.new()
	output.node_id = transform_count + 2
	graph.nodes.append(output)
	graph.connections.append(ScatterConnection.create(previous.node_id, &"instances", output.node_id, &"instances"))
	graph.next_node_id = output.node_id + 1
	return graph
