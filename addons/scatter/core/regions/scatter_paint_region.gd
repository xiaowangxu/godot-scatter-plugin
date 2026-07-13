@tool
class_name ScatterPaintRegion
extends ScatterRegionValue

var strokes: Array[ScatterPaintStroke] = []
var depth := 0.35
var surface_offset := 0.0


func _init(
		p_strokes: Array[ScatterPaintStroke] = [],
		p_depth := 0.35,
		p_surface_offset := 0.0,
) -> void:
	strokes = p_strokes
	depth = maxf(p_depth, 0.01)
	surface_offset = p_surface_offset


func get_bounds() -> AABB:
	if strokes.is_empty():
		return AABB()
	var first := strokes[0]
	var first_radius := maxf(first.radius, 0.001)
	var result := AABB(first.position - Vector3.ONE * first_radius, Vector3.ONE * first_radius * 2.0)
	for stroke in strokes:
		var radius := maxf(stroke.radius, 0.001)
		result = result.merge(AABB(stroke.position - Vector3.ONE * radius, Vector3.ONE * radius * 2.0))
	return result.grow(depth * 0.5)


func contains(point: Vector3) -> bool:
	for stroke in strokes:
		var normal := stroke.normal.normalized()
		var center := stroke.position + normal * surface_offset
		var delta := point - center
		if absf(delta.dot(normal)) <= depth * 0.5:
			var tangent_delta := delta - normal * delta.dot(normal)
			if tangent_delta.length_squared() <= stroke.radius * stroke.radius:
				return true
	return false


func is_empty() -> bool:
	return strokes.is_empty()


func sample(rng: RandomNumberGenerator, _flat: bool) -> Vector3:
	if strokes.is_empty():
		return Vector3.INF
	var stroke := strokes[rng.randi_range(0, strokes.size() - 1)]
	var normal := stroke.normal.normalized()
	var tangent := normal.cross(Vector3.FORWARD).normalized()
	if tangent.length_squared() < 0.001:
		tangent = normal.cross(Vector3.RIGHT).normalized()
	var bitangent := normal.cross(tangent).normalized()
	var radius := sqrt(rng.randf()) * maxf(stroke.radius, 0.001)
	var angle := rng.randf() * TAU
	return (
		stroke.position
		+ normal * surface_offset
		+ tangent * cos(angle) * radius
		+ bitangent * sin(angle) * radius
	)
