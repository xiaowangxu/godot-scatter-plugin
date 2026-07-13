extends SceneTree


func _init() -> void:
	var ring := ScatterGizmoPlugin._circle_lines(Vector3(1, 2, 3), Vector3.UP, 2.0, true)
	assert(ring.size() == 102, "Brush cursor must contain a 48-segment ring, cross and normal indicator")
	for point in ring:
		assert(point.is_finite())
	var paint := {
		"type": "paint_region",
		"params": {
			"strokes": [{"position": Vector3.ZERO, "normal": Vector3.UP, "radius": 2.0}],
			"surface_offset": 0.0,
		}
	}
	var lines := ScatterGizmoPlugin._region_lines(paint)
	assert(lines.size() == 96, "Each painted stamp must have a persistent viewport outline")
	print("Scatter paint preview test passed: %d cursor vertices, %d stamp vertices" % [ring.size(), lines.size()])
	quit(0)
