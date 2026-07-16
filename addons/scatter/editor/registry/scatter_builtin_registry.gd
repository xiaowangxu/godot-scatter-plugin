@tool
class_name ScatterBuiltinRegistry
extends RefCounted

const DefaultExtension := preload("res://addons/scatter/editor/extensions/scatter_default_editor_extension.gd")
const PathExtension := preload("res://addons/scatter/editor/extensions/scatter_path_editor_extension.gd")
const PaintExtension := preload("res://addons/scatter/editor/extensions/scatter_paint_editor_extension.gd")
const GenericView := preload("res://addons/scatter/editor/graph/views/scatter_builtin_node_view.gd")
const FinalOutputView := preload("res://addons/scatter/editor/graph/views/scatter_final_output_view.gd")
const PaintRegionView := preload("res://addons/scatter/editor/graph/views/scatter_paint_region_view.gd")

const ENTRIES := [
	[preload("res://addons/scatter/core/nodes/region/scatter_path_extrude_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/region/scatter_path_tube_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/region/scatter_shape_transform_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/output/scatter_final_output_node.gd"), FinalOutputView],
	[preload("res://addons/scatter/core/nodes/region/scatter_box_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/region/scatter_sphere_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/region/scatter_path_node.gd"), GenericView, PathExtension],
	[preload("res://addons/scatter/core/nodes/region/scatter_paint_region_node.gd"), PaintRegionView, PaintExtension],
	[preload("res://addons/scatter/core/nodes/region/scatter_union_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/region/scatter_intersection_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/region/scatter_subtract_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/placement/scatter_random_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/placement/scatter_grid_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/placement/scatter_poisson_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/placement/scatter_edge_random_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/placement/scatter_edge_even_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/placement/scatter_edge_continuous_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/placement/scatter_single_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/placement/scatter_merge_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/transform/scatter_array_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/transform/scatter_transform_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/transform/scatter_position_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/transform/scatter_rotation_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/transform/scatter_scale_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/transform/scatter_random_transform_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/transform/scatter_random_rotation_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/transform/scatter_look_at_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/transform/scatter_snap_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/transform/scatter_relax_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/transform/scatter_clusterize_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/transform/scatter_project_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/filter/scatter_remove_outside_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/filter/scatter_remove_random_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/data/scatter_proxy_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/data/scatter_random_color_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/data/scatter_set_color_node.gd"), GenericView],
	[preload("res://addons/scatter/core/nodes/data/scatter_random_custom_data_node.gd"), GenericView],
]


static func register_all() -> void:
	for entry in ENTRIES:
		var node_script: Script = entry[0]
		var view_script: Script = entry[1]
		var prototype := node_script.new() as ScatterNode
		if ScatterNodeRegistry.create_node(prototype.get_type_id()) == null:
			ScatterExtensionRegistry.register_node(node_script, view_script, entry[2] if entry.size() > 2 else DefaultExtension)


static func unregister_all() -> void:
	for entry in ENTRIES:
		var prototype := (entry[0] as Script).new() as ScatterNode
		ScatterExtensionRegistry.unregister_node(prototype.get_type_id())
