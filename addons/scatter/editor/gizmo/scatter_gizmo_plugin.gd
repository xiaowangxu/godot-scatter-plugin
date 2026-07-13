@tool
class_name ScatterGizmoPlugin
extends EditorNode3DGizmoPlugin

var _brush_previews: Dictionary[int, Dictionary] = {}


func _init() -> void:
	create_material("region", Color(0.28, 0.82, 0.72, 0.95))
	create_material("paint", Color(0.22, 0.72, 1.0, 0.9))
	create_material("disconnected", Color(0.48, 0.52, 0.58, 0.38))
	create_material("cursor", Color(0.35, 1.0, 0.45, 1.0))
	create_material("erase", Color(1.0, 0.28, 0.32, 1.0))


func _get_gizmo_name() -> String:
	return "Scatter Regions"


func _get_priority() -> int:
	return 1


func _has_gizmo(node_3d: Node3D) -> bool:
	return node_3d is MultiMeshInstance3D and ScatterGraphAttachment.get_graph(node_3d) != null


func set_brush_preview(
		target: MultiMeshInstance3D,
		position: Vector3,
		normal: Vector3,
		radius: float,
		erase: bool,
) -> void:
	if not is_instance_valid(target):
		return
	_brush_previews[target.get_instance_id()] = {
		"position": position,
		"normal": normal,
		"radius": radius,
		"erase": erase,
	}
	target.update_gizmos()


func clear_brush_preview(target: MultiMeshInstance3D) -> void:
	if not is_instance_valid(target):
		return
	_brush_previews.erase(target.get_instance_id())
	target.update_gizmos()


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var target := gizmo.get_node_3d() as MultiMeshInstance3D
	if not is_instance_valid(target):
		return
	var graph := ScatterGraphAttachment.get_graph(target)
	if graph == null:
		return
	var connected_ids := _connected_node_ids(graph)
	for node in graph.nodes:
		if not node.enabled or not node is ScatterRegionNode:
			continue
		var lines := node.get_preview_lines()
		if lines.is_empty():
			continue
		var material_name := "disconnected"
		if connected_ids.has(node.node_id):
			material_name = "paint" if node is ScatterPaintRegionNode else "region"
		gizmo.add_lines(lines, get_material(material_name, gizmo), false)
	var preview: Dictionary = _brush_previews.get(target.get_instance_id(), {})
	if not preview.is_empty():
		var cursor_lines := ScatterBrushGeometry.circle(
			preview.position,
			preview.normal,
			preview.radius,
			true,
		)
		gizmo.add_lines(cursor_lines, get_material("erase" if preview.erase else "cursor", gizmo), false)


func _connected_node_ids(graph: ScatterGraph) -> Dictionary[int, bool]:
	var result: Dictionary[int, bool] = {}
	var output := graph.final_output_node()
	if output == null:
		return result
	var pending: Array[int] = [output.node_id]
	while not pending.is_empty():
		var node_id := pending.pop_back()
		if result.has(node_id):
			continue
		result[node_id] = true
		for connection in graph.connections:
			if connection.to_node_id == node_id:
				pending.append(connection.from_node_id)
	return result
