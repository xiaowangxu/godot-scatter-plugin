@tool
class_name ScatterPathRegion
extends ScatterRegionValue

var points := PackedVector3Array()
var thickness := 1.0
var closed := false


func _init(
		p_points := PackedVector3Array(),
		p_thickness := 1.0,
		p_closed := false,
) -> void:
	points = p_points
	thickness = maxf(p_thickness, 0.0)
	closed = p_closed


func get_bounds() -> AABB:
	if points.is_empty():
		return AABB()
	var result := AABB(points[0], Vector3.ZERO)
	for point in points:
		result = result.expand(point)
	return result.grow(maxf(thickness, 0.001))


func contains(point: Vector3) -> bool:
	for edge in get_edges():
		if ScatterMath.distance_to_segment(point, edge.a, edge.b) <= thickness:
			return true
	return false


func is_empty() -> bool:
	return points.size() < 2


func get_edges() -> Array[ScatterEdge]:
	var result: Array[ScatterEdge] = []
	for index in maxi(0, points.size() - 1):
		result.append(ScatterEdge.new(points[index], points[index + 1]))
	if closed and points.size() > 2:
		result.append(ScatterEdge.new(points[-1], points[0]))
	return result
