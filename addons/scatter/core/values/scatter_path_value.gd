@tool
class_name ScatterPathValue
extends ScatterValue

var _points: PackedVector3Array
var _closed := false
var _cumulative_lengths := PackedFloat32Array()
var _length := 0.0


func _init(points := PackedVector3Array(), closed := false) -> void:
	_points = points.duplicate()
	_closed = closed
	_rebuild_lengths()


func get_value_type_id() -> StringName:
	return ScatterValueTypeRegistry.PATH


func get_points_local() -> PackedVector3Array:
	return _points.duplicate()


func is_closed() -> bool:
	return _closed


func get_length_local() -> float:
	return _length


func sample_local(value: float) -> Vector3:
	if _points.is_empty():
		return Vector3.INF
	if _points.size() == 1 or _length <= 0.000001:
		return _points[0]
	var distance := clampf(value, 0.0, 1.0) * _length
	var segment := _segment_for_distance(distance)
	var start_distance := _cumulative_lengths[segment]
	var end_distance := _cumulative_lengths[segment + 1]
	var t := inverse_lerp(start_distance, end_distance, distance)
	return _segment_point(segment, t)


func tangent_local(value: float) -> Vector3:
	if _points.size() < 2:
		return Vector3.FORWARD
	var segment := _segment_for_distance(clampf(value, 0.0, 1.0) * _length)
	var tangent := _segment_end(segment) - _points[segment]
	return tangent.normalized() if not tangent.is_zero_approx() else Vector3.FORWARD


func _rebuild_lengths() -> void:
	_cumulative_lengths = PackedFloat32Array([0.0])
	_length = 0.0
	var segment_count := _points.size() if _closed and _points.size() > 1 else maxi(0, _points.size() - 1)
	for index in segment_count:
		_length += _points[index].distance_to(_segment_end(index))
		_cumulative_lengths.append(_length)


func _segment_for_distance(distance: float) -> int:
	var segment_count := _cumulative_lengths.size() - 1
	for index in segment_count:
		if distance <= _cumulative_lengths[index + 1]:
			return index
	return maxi(0, segment_count - 1)


func _segment_end(segment: int) -> Vector3:
	return _points[(segment + 1) % _points.size()]


func _segment_point(segment: int, t: float) -> Vector3:
	return _points[segment].lerp(_segment_end(segment), t)
