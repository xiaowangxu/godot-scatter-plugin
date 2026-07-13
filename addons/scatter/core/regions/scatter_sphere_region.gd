@tool
class_name ScatterSphereRegion
extends ScatterRegionValue

var center := Vector3.ZERO
var radius := 1.0


func _init(p_center := Vector3.ZERO, p_radius := 1.0) -> void:
	center = p_center
	radius = maxf(p_radius, 0.001)


func get_bounds() -> AABB:
	return AABB(center - Vector3.ONE * radius, Vector3.ONE * radius * 2.0)


func contains(point: Vector3) -> bool:
	return point.distance_squared_to(center) <= radius * radius


func get_edges() -> Array[ScatterEdge]:
	var result: Array[ScatterEdge] = []
	for axis in 3:
		for index in 32:
			var angle_a := TAU * float(index) / 32.0
			var angle_b := TAU * float(index + 1) / 32.0
			var a := Vector3(cos(angle_a) * radius, 0.0, sin(angle_a) * radius)
			var b := Vector3(cos(angle_b) * radius, 0.0, sin(angle_b) * radius)
			if axis == 1:
				a = Vector3(a.x, a.z, 0.0)
				b = Vector3(b.x, b.z, 0.0)
			elif axis == 2:
				a = Vector3(0.0, a.x, a.z)
				b = Vector3(0.0, b.x, b.z)
			result.append(ScatterEdge.new(center + a, center + b))
	return result
