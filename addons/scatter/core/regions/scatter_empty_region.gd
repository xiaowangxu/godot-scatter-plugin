@tool
class_name ScatterEmptyRegion
extends ScatterRegionValue


func get_bounds() -> AABB:
	return AABB()


func contains(_point: Vector3) -> bool:
	return false


func is_empty() -> bool:
	return true


func sample(_rng: RandomNumberGenerator, _flat: bool) -> Vector3:
	return Vector3.INF
