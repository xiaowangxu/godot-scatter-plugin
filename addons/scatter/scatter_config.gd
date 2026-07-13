@tool
class_name ScatterConfig
extends Resource

## Serialized directly in a MultiMeshInstance3D metadata entry. The scene keeps
## the recipe without requiring a custom node or script on the target.

@export var version: int = 3
@export var seed: int = 0
@export var nodes: Array[Dictionary] = []
@export var connections: Array[Dictionary] = []
@export var manual_transforms: Array[Transform3D] = []
@export var manual_colors: Array[Color] = []
@export var manual_custom_data: Array[Color] = []
@export var auto_rebuild: bool = true
@export var collision_mask: int = 1
@export var next_id: int = 1


func allocate_id() -> int:
	var result := next_id
	next_id += 1
	return result


func add_node(type: StringName, position := Vector2.ZERO) -> Dictionary:
	var entry := {
		"id": allocate_id(),
		"type": String(type),
		"enabled": true,
		"override_seed": false,
		"custom_seed": 0,
		"position": position,
		"params": ScatterSchema.defaults_for(type),
	}
	nodes.append(entry)
	emit_changed()
	return entry


func find_node(id: int) -> Dictionary:
	for entry in nodes:
		if int(entry.get("id", 0)) == id:
			return entry
	return {}


func output_node() -> Dictionary:
	return final_output_node()


func final_output_node() -> Dictionary:
	for entry in nodes:
		if entry.get("type", "") == "final_output":
			return entry
	return {}


func group_nodes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in nodes:
		if entry.get("type", "") == "group":
			result.append(entry)
	return result


func final_input_count() -> int:
	var final_output := final_output_node()
	if final_output.is_empty():
		return 1
	var highest_port := -1
	for connection in connections:
		if int(connection.get("to_id", 0)) == int(final_output.id):
			highest_port = maxi(highest_port, int(connection.get("to_port", 0)))
	# Keep one empty socket ready so adding the next Scatter Set never needs a
	# separate UI command.
	return maxi(1, highest_port + 2)


func connect_nodes(from_id: int, from_port: int, to_id: int, to_port: int) -> void:
	# Every input socket has a single source. Outputs may fan out.
	for i in range(connections.size() - 1, -1, -1):
		var connection := connections[i]
		if int(connection.get("to_id", 0)) == to_id and int(connection.get("to_port", 0)) == to_port:
			connections.remove_at(i)
	connections.append({
		"from_id": from_id,
		"from_port": from_port,
		"to_id": to_id,
		"to_port": to_port,
	})
	emit_changed()


func disconnect_nodes(from_id: int, from_port: int, to_id: int, to_port: int) -> void:
	for i in range(connections.size() - 1, -1, -1):
		var connection := connections[i]
		if (int(connection.get("from_id", 0)) == from_id
				and int(connection.get("from_port", 0)) == from_port
				and int(connection.get("to_id", 0)) == to_id
				and int(connection.get("to_port", 0)) == to_port):
			connections.remove_at(i)
	emit_changed()


func incoming_connection(to_id: int, to_port: int) -> Dictionary:
	for connection in connections:
		if int(connection.get("to_id", 0)) == to_id and int(connection.get("to_port", 0)) == to_port:
			return connection
	return {}


func remove_node(id: int) -> void:
	for i in range(nodes.size() - 1, -1, -1):
		if int(nodes[i].get("id", 0)) == id:
			nodes.remove_at(i)
	for i in range(connections.size() - 1, -1, -1):
		var connection := connections[i]
		if int(connection.get("from_id", 0)) == id or int(connection.get("to_id", 0)) == id:
			connections.remove_at(i)
	emit_changed()


func would_create_cycle(from_id: int, to_id: int) -> bool:
	if from_id == to_id:
		return true
	var pending: Array[int] = [to_id]
	var visited := {}
	while not pending.is_empty():
		var current := pending.pop_back()
		if current == from_id:
			return true
		if visited.has(current):
			continue
		visited[current] = true
		for connection in connections:
			if int(connection.get("from_id", 0)) == current:
				pending.append(int(connection.get("to_id", 0)))
	return false


func ensure_graph() -> void:
	var max_id := 0
	var first_final_id := 0
	var duplicate_finals: Array[int] = []
	for entry in nodes:
		var id := int(entry.get("id", 0))
		max_id = maxi(max_id, id)
		# Godot 4.7 recipes created by v2 used Output as Region + Placement.
		# It is now a Group and keeps the same id, position and incoming wires.
		if entry.get("type", "") == "output":
			entry.type = "group"
		elif entry.get("type", "") == "final_output":
			if first_final_id == 0: first_final_id = id
			else: duplicate_finals.append(id)
	next_id = maxi(next_id, max_id + 1)
	for id in duplicate_finals:
		remove_node(id)
	_sanitize_connections()

	var rightmost := 40.0
	for entry in nodes:
		rightmost = maxf(rightmost, Vector2(entry.get("position", Vector2.ZERO)).x)

	# Version 1 recipes stored an ordered list and drew decorative wires. Turn
	# that list into one Group before adding the aggregate Final Output.
	if group_nodes().is_empty():
		var legacy_nodes := nodes.duplicate()
		var positive_regions: Array[Dictionary] = []
		var negative_regions: Array[Dictionary] = []
		var placements: Array[Dictionary] = []
		for entry in legacy_nodes:
			if ScatterSchema.is_region_source(entry.get("type", "")):
				if entry.get("params", {}).get("negative", false):
					entry["params"]["negative"] = false
					negative_regions.append(entry)
				else:
					positive_regions.append(entry)
			elif ScatterSchema.is_placement(entry.get("type", "")):
				placements.append(entry)

		var region_root := 0
		for entry in positive_regions:
			if region_root == 0:
				region_root = int(entry.get("id", 0))
			else:
				var combine := add_node(&"region_union", Vector2(rightmost + 300, 40 + region_root % 4 * 100))
				connect_nodes(region_root, 0, combine.id, 0)
				connect_nodes(int(entry.get("id", 0)), 0, combine.id, 1)
				region_root = int(combine.id)
				rightmost += 300
		for entry in negative_regions:
			if region_root == 0:
				continue
			var subtract := add_node(&"region_subtract", Vector2(rightmost + 300, 120))
			connect_nodes(region_root, 0, subtract.id, 0)
			connect_nodes(int(entry.get("id", 0)), 0, subtract.id, 1)
			region_root = int(subtract.id)
			rightmost += 300

		for i in range(placements.size() - 1):
			connect_nodes(int(placements[i].get("id", 0)), 0, int(placements[i + 1].get("id", 0)), 0)

		var group_position := Vector2(rightmost + 420, 160)
		if not placements.is_empty():
			group_position.x = maxf(group_position.x, Vector2(placements[-1].get("position", Vector2.ZERO)).x + 360)
		var group := add_node(&"group", group_position)
		if region_root != 0:
			connect_nodes(region_root, 0, int(group.id), 0)
		if not placements.is_empty():
			connect_nodes(int(placements[-1].get("id", 0)), 0, int(group.id), 1)
		rightmost = maxf(rightmost, group_position.x)

	if final_output_node().is_empty():
		var final_output := add_node(&"final_output", Vector2(rightmost + 340, 180))
		var port := 0
		for group in group_nodes():
			connect_nodes(int(group.id), 0, int(final_output.id), port)
			port += 1

	_sanitize_connections()
	_compact_final_inputs()
	version = 3
	emit_changed()


func _sanitize_connections() -> void:
	var valid_ids := {}
	for entry in nodes:
		valid_ids[int(entry.get("id", 0))] = true
	for i in range(connections.size() - 1, -1, -1):
		var connection := connections[i]
		var to_entry := find_node(int(connection.get("to_id", 0)))
		if (not valid_ids.has(int(connection.get("from_id", 0)))
				or not valid_ids.has(int(connection.get("to_id", 0)))
				or ScatterSchema.is_placement_source(to_entry.get("type", ""))):
			connections.remove_at(i)


func _compact_final_inputs() -> void:
	var final_output := final_output_node()
	if final_output.is_empty(): return
	var incoming: Array[Dictionary] = []
	for connection in connections:
		if int(connection.get("to_id", 0)) == int(final_output.id): incoming.append(connection)
	incoming.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("to_port", 0)) < int(b.get("to_port", 0)))
	for port in incoming.size(): incoming[port].to_port = port


func duplicate_recipe() -> ScatterConfig:
	var copy := ScatterConfig.new()
	copy.version = version
	copy.seed = seed
	copy.nodes = nodes.duplicate(true)
	copy.connections = connections.duplicate(true)
	copy.manual_transforms = manual_transforms.duplicate()
	copy.manual_colors = manual_colors.duplicate()
	copy.manual_custom_data = manual_custom_data.duplicate()
	copy.auto_rebuild = auto_rebuild
	copy.collision_mask = collision_mask
	copy.next_id = next_id
	return copy
