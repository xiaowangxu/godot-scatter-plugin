@tool
class_name ScatterGroupNode
extends ScatterNode


func get_type_id() -> StringName:
	return &"group"


func get_caption() -> String:
	return "Scatter Group"


func get_category() -> StringName:
	return &"Group"


func get_color() -> Color:
	return Color("c48745")


func get_input_ports() -> Array[ScatterPort]:
	return [
		ScatterPort.new(&"region", "Region", ScatterPort.ValueType.REGION),
		ScatterPort.new(&"placement", "Placement", ScatterPort.ValueType.INSTANCES),
	]


func get_output_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"set", "Scatter Set", ScatterPort.ValueType.SCATTER_SET)]


func prepare_input_context(
		port_id: StringName,
		context: ScatterEvaluationContext,
		inputs: ScatterNodeInputs,
) -> ScatterEvaluationContext:
	if port_id == &"placement":
		var active_region := inputs.region(&"region")
		return context.with_region(active_region if active_region != null else ScatterEmptyRegion.new())
	return context


func evaluate(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var instances := inputs.instances(&"placement")
	if instances == null:
		instances = context.take_manual_instances()
	else:
		instances = instances.duplicate_buffer()
	instances.limit(context.maximum_instances)
	context.session.group_counts[node_id] = instances.transforms.size()
	return ScatterSetValue.new(instances, node_id)


func evaluate_disabled(context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterValue:
	context.session.group_counts[node_id] = 0
	return ScatterSetValue.new(ScatterInstanceBuffer.new(), node_id)
