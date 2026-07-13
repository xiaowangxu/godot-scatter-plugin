@tool
class_name ScatterInstanceBuffer
extends ScatterValue

@export var transforms: Array[Transform3D] = []
@export var colors: Array[Color] = []
@export var custom_data: Array[Color] = []


func get_value_type() -> int:
	return ScatterPort.ValueType.INSTANCES


func duplicate_buffer() -> ScatterInstanceBuffer:
	var copy := ScatterInstanceBuffer.new()
	copy.transforms = transforms.duplicate()
	copy.colors = colors.duplicate()
	copy.custom_data = custom_data.duplicate()
	return copy


func append_buffer(other: ScatterInstanceBuffer, maximum := -1) -> void:
	if other == null:
		return
	var amount := other.transforms.size()
	if maximum >= 0:
		amount = mini(amount, maxi(0, maximum - transforms.size()))
	for index in amount:
		transforms.append(other.transforms[index])
		colors.append(other.colors[index] if index < other.colors.size() else Color.WHITE)
		custom_data.append(other.custom_data[index] if index < other.custom_data.size() else Color(0, 0, 0, 0))


func normalize() -> void:
	if colors.size() > transforms.size():
		colors.resize(transforms.size())
	if custom_data.size() > transforms.size():
		custom_data.resize(transforms.size())
	while colors.size() < transforms.size():
		colors.append(Color.WHITE)
	while custom_data.size() < transforms.size():
		custom_data.append(Color(0, 0, 0, 0))


func limit(maximum: int) -> void:
	if transforms.size() > maximum:
		transforms.resize(maximum)
	normalize()


func remove_at(index: int) -> void:
	transforms.remove_at(index)
	if index < colors.size():
		colors.remove_at(index)
	if index < custom_data.size():
		custom_data.remove_at(index)


func is_empty() -> bool:
	return transforms.is_empty()
