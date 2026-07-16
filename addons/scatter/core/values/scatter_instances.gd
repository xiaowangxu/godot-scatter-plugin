@tool
class_name ScatterInstances
extends ScatterValue

var transforms: Array[Transform3D] = []
var colors: Array[Color] = []
var custom_data: Array[Color] = []


func get_value_type_id() -> StringName:
	return ScatterValueTypeRegistry.INSTANCES


func duplicate_value() -> ScatterValue:
	return duplicate_instances()


func duplicate_instances() -> ScatterInstances:
	var copy := ScatterInstances.new()
	copy.transforms = transforms.duplicate()
	copy.colors = colors.duplicate()
	copy.custom_data = custom_data.duplicate()
	return copy


func add_instance(transform: Transform3D, color := Color.WHITE, data := Color(0, 0, 0, 0)) -> void:
	transforms.append(transform)
	colors.append(color)
	custom_data.append(data)


func append_instances(other: ScatterInstances, maximum := -1) -> void:
	if other == null:
		return
	var amount := other.transforms.size()
	if maximum >= 0:
		amount = mini(amount, maxi(0, maximum - transforms.size()))
	if amount <= 0:
		return
	transforms.append_array(other.transforms.slice(0, amount))
	if other.colors.size() >= amount:
		colors.append_array(other.colors.slice(0, amount))
	else:
		for index in amount:
			colors.append(other.colors[index] if index < other.colors.size() else Color.WHITE)
	if other.custom_data.size() >= amount:
		custom_data.append_array(other.custom_data.slice(0, amount))
	else:
		for index in amount:
			custom_data.append(other.custom_data[index] if index < other.custom_data.size() else Color.TRANSPARENT)


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
	normalize()
	transforms.remove_at(index)
	colors.remove_at(index)
	custom_data.remove_at(index)


func compact(keep: PackedByteArray) -> void:
	normalize()
	var write_index := 0
	var amount := mini(transforms.size(), keep.size())
	for read_index in amount:
		if keep[read_index] == 0:
			continue
		if write_index != read_index:
			transforms[write_index] = transforms[read_index]
			colors[write_index] = colors[read_index]
			custom_data[write_index] = custom_data[read_index]
		write_index += 1
	transforms.resize(write_index)
	colors.resize(write_index)
	custom_data.resize(write_index)


func is_empty() -> bool:
	return transforms.is_empty()
