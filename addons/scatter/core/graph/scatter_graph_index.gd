@tool
class_name ScatterGraphIndex
extends RefCounted

var graph: ScatterGraph
var duplicate_node_ids: Array[int] = []

var _nodes: Dictionary[int, ScatterNode] = {}
var _node_ids: Array[int] = []
var _incoming: Dictionary = {}
var _outgoing: Dictionary = {}
var _incoming_ports: Dictionary = {}
var _outgoing_ports: Dictionary = {}


func _init(p_graph: ScatterGraph = null) -> void:
	if p_graph != null:
		rebuild(p_graph)


func rebuild(p_graph: ScatterGraph) -> void:
	graph = p_graph
	duplicate_node_ids.clear()
	_nodes.clear()
	_node_ids.clear()
	_incoming.clear()
	_outgoing.clear()
	_incoming_ports.clear()
	_outgoing_ports.clear()
	if graph == null:
		return
	for node in graph.nodes:
		if node == null:
			continue
		if _nodes.has(node.node_id):
			if not duplicate_node_ids.has(node.node_id):
				duplicate_node_ids.append(node.node_id)
			continue
		_nodes[node.node_id] = node
		_node_ids.append(node.node_id)
		_incoming[node.node_id] = [] as Array[ScatterConnection]
		_outgoing[node.node_id] = [] as Array[ScatterConnection]
	for connection in graph.connections:
		if connection == null:
			continue
		if _incoming.has(connection.to_node_id):
			(_incoming[connection.to_node_id] as Array).append(connection)
			_append_port_connection(_incoming_ports, connection.to_node_id, connection.to_port_id, connection)
		if _outgoing.has(connection.from_node_id):
			(_outgoing[connection.from_node_id] as Array).append(connection)
			_append_port_connection(_outgoing_ports, connection.from_node_id, connection.from_port_id, connection)
	for values in _incoming.values():
		(values as Array).sort_custom(func(a: ScatterConnection, b: ScatterConnection) -> bool:
			return a.order < b.order
		)
	for values in _incoming_ports.values():
		(values as Array).sort_custom(func(a: ScatterConnection, b: ScatterConnection) -> bool:
			return a.order < b.order
		)


func find_node(node_id: int) -> ScatterNode:
	return _nodes.get(node_id)


func node_ids() -> Array[int]:
	return _node_ids


func incoming_connections(node_id: int, port_id: StringName = &"") -> Array[ScatterConnection]:
	return _incoming.get(node_id, []) if port_id.is_empty() else _incoming_ports.get(_port_key(node_id, port_id), [])


func outgoing_connections(node_id: int, port_id: StringName = &"") -> Array[ScatterConnection]:
	return _outgoing.get(node_id, []) if port_id.is_empty() else _outgoing_ports.get(_port_key(node_id, port_id), [])


func _append_port_connection(
		groups: Dictionary,
		node_id: int,
		port_id: StringName,
		connection: ScatterConnection,
) -> void:
	var key := _port_key(node_id, port_id)
	if not groups.has(key):
		groups[key] = [] as Array[ScatterConnection]
	(groups[key] as Array).append(connection)


func _port_key(node_id: int, port_id: StringName) -> String:
	return "%d:%s" % [node_id, port_id]
