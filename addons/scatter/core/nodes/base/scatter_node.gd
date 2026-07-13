@tool
@abstract
class_name ScatterNode
extends Resource

@export var node_id := 0
@export var graph_position := Vector2.ZERO
@export var enabled := true
@export var override_seed := false
@export var custom_seed := 0


@abstract func get_type_id() -> StringName


@abstract func get_caption() -> String


@abstract func get_category() -> StringName


@abstract func get_input_ports() -> Array[ScatterPort]


@abstract func get_output_ports() -> Array[ScatterPort]


@abstract func evaluate(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue


func evaluate_disabled(_context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	for port in get_input_ports():
		var value := inputs.first(port.id)
		if value != null:
			return value
	return null


func prepare_input_context(
		_port_id: StringName,
		context: ScatterEvaluationContext,
		_inputs: ScatterNodeInputs,
) -> ScatterEvaluationContext:
	return context


func get_color() -> Color:
	return Color("657383")


func get_description() -> String:
	return get_caption()


func supports_seed() -> bool:
	return false


func can_disable() -> bool:
	return true


func is_deletable() -> bool:
	return true


func validate(_context: ScatterEvaluationContext) -> PackedStringArray:
	return PackedStringArray()


func get_preview_lines() -> PackedVector3Array:
	return PackedVector3Array()


func input_port(port_id: StringName) -> ScatterPort:
	for port in get_input_ports():
		if port.id == port_id:
			return port
	return null


func output_port(port_id: StringName) -> ScatterPort:
	for port in get_output_ports():
		if port.id == port_id:
			return port
	return null
