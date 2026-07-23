@tool
class_name ScatterPathPlanarNode
extends ScatterRegionNode

@export var normal := Vector3.UP
@export_enum("Polygon Centroid:0", "Path Origin:1") var origin: int = ScatterPlanarRegion.PathOrigin.POLYGON_CENTROID
@export_enum("Require Planar:0", "Project To Plane:1") var non_planar_policy: int = ScatterPlanarRegion.NonPlanarPolicy.PROJECT_TO_PLANE
@export_range(0.000001, 1000.0, 0.0001) var planarity_tolerance := 0.001


func get_type_id() -> StringName:
	return &"path_planar_region"


func get_caption() -> String:
	return "Path To Planar Region"


func get_color() -> Color:
	return Color("3fae9a")


func get_input_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"path", "Closed Path", ScatterValueTypeRegistry.PATH)]


func get_output_ports() -> Array[ScatterPort]:
	return [ScatterPort.new(&"region", "Planar Region", ScatterValueTypeRegistry.PLANAR_REGION)]


func evaluate_value(context: ScatterEvaluationContext, inputs: ScatterNodeInputs) -> ScatterValue:
	var path := inputs.path()
	if path == null or not path.is_closed():
		if context != null:
			context.add_error(
				&"planar_region_requires_closed_path",
				node_id,
				"Path To Planar Region requires a closed Path.",
			)
		return ScatterPlanarRegion.new()
	var region := ScatterPlanarRegion.from_path(
		path,
		normal,
		origin,
		non_planar_policy,
		planarity_tolerance,
	)
	if region.is_empty() and context != null:
		context.add_error(
			&"invalid_planar_polygon",
			node_id,
			"Path could not be converted to a simple planar polygon.",
			{"policy": non_planar_policy, "tolerance": planarity_tolerance},
		)
	return region


func validate(_context: ScatterEvaluationContext) -> PackedStringArray:
	var errors := PackedStringArray()
	if normal.is_zero_approx():
		errors.append("Path To Planar Region normal must be non-zero.")
	if planarity_tolerance <= 0.0:
		errors.append("Path To Planar Region tolerance must be greater than zero.")
	return errors
