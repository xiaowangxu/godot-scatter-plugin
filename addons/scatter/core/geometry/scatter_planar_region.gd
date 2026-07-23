@tool
class_name ScatterPlanarRegion
extends ScatterRegionValue

enum PathOrigin {
	POLYGON_CENTROID,
	PATH_ORIGIN,
}

enum NonPlanarPolicy {
	REQUIRE_PLANAR,
	PROJECT_TO_PLANE,
}

const EPSILON := 0.00001

var frame := Transform3D.IDENTITY
var polygon := PackedVector2Array()

var _triangles := PackedInt32Array()
var _triangle_cumulative_areas := PackedFloat32Array()
var _area := 0.0


func _init(
		p_polygon := PackedVector2Array(),
	p_frame := Transform3D.IDENTITY,
	) -> void:
	polygon = p_polygon.duplicate()
	frame = Transform3D(p_frame.basis.orthonormalized(), p_frame.origin)
	_rebuild()


static func from_path(
		path: ScatterPathValue,
		normal: Vector3,
		origin_mode: int = PathOrigin.POLYGON_CENTROID,
		non_planar_policy: int = NonPlanarPolicy.REQUIRE_PLANAR,
		planarity_tolerance: float = 0.001,
	) -> ScatterPlanarRegion:
	if path == null or not path.is_closed():
		return ScatterPlanarRegion.new()
	var points := path.get_points_local()
	if points.size() < 3:
		return ScatterPlanarRegion.new()
	var plane_normal := normal.normalized() if not normal.is_zero_approx() else Vector3.UP
	var plane_origin := Vector3.ZERO
	for point in points:
		plane_origin += point
	plane_origin /= float(points.size())
	var basis := ScatterMath.basis_from_up(plane_normal, path.get_local_transform().basis.z)
	var projected := PackedVector3Array()
	var points_2d := PackedVector2Array()
	var tolerance := maxf(planarity_tolerance, 0.000001)
	for point in points:
		var height := plane_normal.dot(point - plane_origin)
		if non_planar_policy == NonPlanarPolicy.REQUIRE_PLANAR and absf(height) > tolerance:
			return ScatterPlanarRegion.new()
		var point_on_plane := point - plane_normal * height
		var relative := point_on_plane - plane_origin
		var point_2d := Vector2(relative.dot(basis.x), relative.dot(basis.z))
		if not points_2d.is_empty() and points_2d[-1].distance_squared_to(point_2d) <= EPSILON * EPSILON:
			continue
		projected.append(point_on_plane)
		points_2d.append(point_2d)
	if points_2d.size() > 1 and points_2d[0].distance_squared_to(points_2d[-1]) <= EPSILON * EPSILON:
		points_2d.resize(points_2d.size() - 1)
		projected.resize(projected.size() - 1)
	if points_2d.size() < 3:
		return ScatterPlanarRegion.new()
	var centroid_2d := _polygon_centroid(points_2d)
	var frame_origin := plane_origin + basis.x * centroid_2d.x + basis.z * centroid_2d.y
	if origin_mode == PathOrigin.PATH_ORIGIN:
		var path_origin := path.get_local_transform().origin
		frame_origin = path_origin - plane_normal * plane_normal.dot(path_origin - plane_origin)
	var rebased := PackedVector2Array()
	for point in projected:
		var relative := point - frame_origin
		rebased.append(Vector2(relative.dot(basis.x), relative.dot(basis.z)))
	return ScatterPlanarRegion.new(rebased, Transform3D(basis, frame_origin))


func get_value_type_id() -> StringName:
	return ScatterValueTypeRegistry.PLANAR_REGION


func get_intrinsic_dimension() -> int:
	return 2


func get_intrinsic_measure_local() -> float:
	return _area


func supports_direct_sampling() -> bool:
	return true


func get_local_transform() -> Transform3D:
	return frame


func get_bounds_local() -> AABB:
	if polygon.is_empty():
		return AABB()
	var first := _point_local(polygon[0])
	var result := AABB(first, Vector3.ZERO)
	for index in range(1, polygon.size()):
		result = result.expand(_point_local(polygon[index]))
	return result


func contains_local(point: Vector3) -> bool:
	if is_empty():
		return false
	var plane_point := frame.affine_inverse() * point
	if absf(plane_point.y) > EPSILON:
		return false
	return _contains_2d(Vector2(plane_point.x, plane_point.z))


func is_empty() -> bool:
	return polygon.size() < 3 or _triangles.is_empty() or _area <= EPSILON


func sample_local(value: float) -> Vector3:
	if is_empty():
		return Vector3.INF
	var target_area := ScatterSampleHash.dimension(value, 0) * _area
	var triangle_slot := 0
	while (
		triangle_slot + 1 < _triangle_cumulative_areas.size()
		and target_area > _triangle_cumulative_areas[triangle_slot]
	):
		triangle_slot += 1
	var triangle_index := triangle_slot * 3
	var a := polygon[_triangles[triangle_index]]
	var b := polygon[_triangles[triangle_index + 1]]
	var c := polygon[_triangles[triangle_index + 2]]
	var root := sqrt(ScatterSampleHash.dimension(value, 1))
	var v := ScatterSampleHash.dimension(value, 2)
	var point_2d := a * (1.0 - root) + b * (root * (1.0 - v)) + c * (root * v)
	return _point_local(point_2d)


func sample_neighbor_local(
		center: Vector3,
		minimum_distance: float,
		maximum_distance: float,
		value: float,
	) -> Vector3:
	var center_in_plane := frame.affine_inverse() * center
	var angle := ScatterSampleHash.dimension(value, 0) * TAU
	var distance := lerpf(
		minimum_distance,
		maximum_distance,
		ScatterSampleHash.dimension(value, 1),
	)
	var point_2d := Vector2(center_in_plane.x, center_in_plane.z)
	point_2d += Vector2(cos(angle), sin(angle)) * distance
	if not _contains_2d(point_2d):
		return Vector3.INF
	return _point_local(point_2d)


func get_edges() -> Array[ScatterEdge]:
	var result: Array[ScatterEdge] = []
	for index in polygon.size():
		result.append(ScatterEdge.new(
			_point_local(polygon[index]),
			_point_local(polygon[(index + 1) % polygon.size()]),
		))
	return result


func _rebuild() -> void:
	_triangles = PackedInt32Array()
	_triangle_cumulative_areas = PackedFloat32Array()
	_area = 0.0
	if polygon.size() < 3:
		return
	_triangles = Geometry2D.triangulate_polygon(polygon)
	for index in range(0, _triangles.size(), 3):
		var a := polygon[_triangles[index]]
		var b := polygon[_triangles[index + 1]]
		var c := polygon[_triangles[index + 2]]
		_area += absf((b - a).cross(c - a)) * 0.5
		_triangle_cumulative_areas.append(_area)


func _point_local(point: Vector2) -> Vector3:
	return frame * Vector3(point.x, 0.0, point.y)


func _contains_2d(point: Vector2) -> bool:
	var inside := false
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		if _distance_squared_to_segment_2d(point, a, b) <= EPSILON * EPSILON:
			return true
		if (a.y > point.y) != (b.y > point.y):
			var crossing_x := (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x
			if point.x < crossing_x:
				inside = not inside
	return inside


static func _polygon_centroid(points: PackedVector2Array) -> Vector2:
	var signed_area := 0.0
	var numerator := Vector2.ZERO
	for index in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		var cross := a.cross(b)
		signed_area += cross
		numerator += (a + b) * cross
	signed_area *= 0.5
	if absf(signed_area) > EPSILON:
		return numerator / (6.0 * signed_area)
	var average := Vector2.ZERO
	for point in points:
		average += point
	return average / float(points.size())


static func _distance_squared_to_segment_2d(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment := b - a
	if segment.length_squared() <= EPSILON * EPSILON:
		return point.distance_squared_to(a)
	var weight := clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_squared_to(a + segment * weight)
