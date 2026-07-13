@tool
class_name ScatterFilterOps
extends RefCounted


static func remove_outside(
		buffer: ScatterInstances,
		region: ScatterShapeValue,
		negative_shapes_only: bool,
) -> void:
	if region == null:
		return
	buffer.normalize()
	for index in range(buffer.transforms.size() - 1, -1, -1):
		var point := buffer.transforms[index].origin
		var should_remove: bool
		if negative_shapes_only and region is ScatterRegionValue:
			should_remove = (region as ScatterRegionValue).contains_exclusion(point)
		else:
			should_remove = not region.contains_local(point)
		if should_remove:
			buffer.remove_at(index)


static func remove_random(
		buffer: ScatterInstances,
		probability_percent: float,
		rng: RandomNumberGenerator,
) -> void:
	buffer.normalize()
	var threshold := clampf(probability_percent / 100.0, 0.0, 1.0)
	for index in range(buffer.transforms.size() - 1, -1, -1):
		if rng.randf() < threshold:
			buffer.remove_at(index)
