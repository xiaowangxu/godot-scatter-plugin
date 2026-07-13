@tool
class_name ScatterFilterOps
extends RefCounted


static func remove_outside(
		buffer: ScatterInstanceBuffer,
		region: ScatterRegionValue,
		negative_shapes_only: bool,
) -> void:
	if region == null:
		return
	buffer.normalize()
	for index in range(buffer.transforms.size() - 1, -1, -1):
		var point := buffer.transforms[index].origin
		var should_remove := region.contains_exclusion(point) if negative_shapes_only else not region.contains(point)
		if should_remove:
			buffer.remove_at(index)


static func remove_random(
		buffer: ScatterInstanceBuffer,
		probability_percent: float,
		rng: RandomNumberGenerator,
) -> void:
	buffer.normalize()
	var threshold := clampf(probability_percent / 100.0, 0.0, 1.0)
	for index in range(buffer.transforms.size() - 1, -1, -1):
		if rng.randf() < threshold:
			buffer.remove_at(index)
