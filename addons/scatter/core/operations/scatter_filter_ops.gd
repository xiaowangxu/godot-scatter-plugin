@tool
class_name ScatterFilterOps
extends RefCounted


static func remove_outside(
		buffer: ScatterInstances,
		shape: ScatterShapeValue,
) -> void:
	if shape == null:
		return
	buffer.normalize()
	var keep := PackedByteArray()
	keep.resize(buffer.transforms.size())
	for index in buffer.transforms.size():
		keep[index] = 1 if shape.contains_local(buffer.transforms[index].origin) else 0
	buffer.compact(keep)


static func remove_random(
		buffer: ScatterInstances,
		probability_percent: float,
		rng: RandomNumberGenerator,
) -> void:
	buffer.normalize()
	var threshold := clampf(probability_percent / 100.0, 0.0, 1.0)
	var keep := PackedByteArray()
	keep.resize(buffer.transforms.size())
	for index in buffer.transforms.size():
		keep[index] = 0 if rng.randf() < threshold else 1
	buffer.compact(keep)
