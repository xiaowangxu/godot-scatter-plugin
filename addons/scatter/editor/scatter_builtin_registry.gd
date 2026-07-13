@tool
class_name ScatterBuiltinRegistry
extends RefCounted

const ENTRIES := [
	[preload("res://addons/scatter/core/nodes/output/scatter_group_node.gd"), preload("res://addons/scatter/editor/views/output/scatter_group_view.gd")],
	[preload("res://addons/scatter/core/nodes/output/scatter_final_output_node.gd"), preload("res://addons/scatter/editor/views/output/scatter_final_output_view.gd")],
	[preload("res://addons/scatter/core/nodes/region/scatter_box_node.gd"), preload("res://addons/scatter/editor/views/region/scatter_box_view.gd")],
	[preload("res://addons/scatter/core/nodes/region/scatter_sphere_node.gd"), preload("res://addons/scatter/editor/views/region/scatter_sphere_view.gd")],
	[preload("res://addons/scatter/core/nodes/region/scatter_path_node.gd"), preload("res://addons/scatter/editor/views/region/scatter_path_view.gd")],
	[preload("res://addons/scatter/core/nodes/region/scatter_paint_region_node.gd"), preload("res://addons/scatter/editor/views/region/scatter_paint_region_view.gd")],
	[preload("res://addons/scatter/core/nodes/region/scatter_union_node.gd"), preload("res://addons/scatter/editor/views/region/scatter_union_view.gd")],
	[preload("res://addons/scatter/core/nodes/region/scatter_intersection_node.gd"), preload("res://addons/scatter/editor/views/region/scatter_intersection_view.gd")],
	[preload("res://addons/scatter/core/nodes/region/scatter_subtract_node.gd"), preload("res://addons/scatter/editor/views/region/scatter_subtract_view.gd")],
	[preload("res://addons/scatter/core/nodes/placement/scatter_random_node.gd"), preload("res://addons/scatter/editor/views/placement/scatter_random_view.gd")],
	[preload("res://addons/scatter/core/nodes/placement/scatter_grid_node.gd"), preload("res://addons/scatter/editor/views/placement/scatter_grid_view.gd")],
	[preload("res://addons/scatter/core/nodes/placement/scatter_poisson_node.gd"), preload("res://addons/scatter/editor/views/placement/scatter_poisson_view.gd")],
	[preload("res://addons/scatter/core/nodes/placement/scatter_edge_random_node.gd"), preload("res://addons/scatter/editor/views/placement/scatter_edge_random_view.gd")],
	[preload("res://addons/scatter/core/nodes/placement/scatter_edge_even_node.gd"), preload("res://addons/scatter/editor/views/placement/scatter_edge_even_view.gd")],
	[preload("res://addons/scatter/core/nodes/placement/scatter_edge_continuous_node.gd"), preload("res://addons/scatter/editor/views/placement/scatter_edge_continuous_view.gd")],
	[preload("res://addons/scatter/core/nodes/placement/scatter_single_node.gd"), preload("res://addons/scatter/editor/views/placement/scatter_single_view.gd")],
	[preload("res://addons/scatter/core/nodes/placement/scatter_merge_node.gd"), preload("res://addons/scatter/editor/views/placement/scatter_merge_view.gd")],
	[preload("res://addons/scatter/core/nodes/transform/scatter_array_node.gd"), preload("res://addons/scatter/editor/views/transform/scatter_array_view.gd")],
	[preload("res://addons/scatter/core/nodes/transform/scatter_transform_node.gd"), preload("res://addons/scatter/editor/views/transform/scatter_transform_view.gd")],
	[preload("res://addons/scatter/core/nodes/transform/scatter_position_node.gd"), preload("res://addons/scatter/editor/views/transform/scatter_position_view.gd")],
	[preload("res://addons/scatter/core/nodes/transform/scatter_rotation_node.gd"), preload("res://addons/scatter/editor/views/transform/scatter_rotation_view.gd")],
	[preload("res://addons/scatter/core/nodes/transform/scatter_scale_node.gd"), preload("res://addons/scatter/editor/views/transform/scatter_scale_view.gd")],
	[preload("res://addons/scatter/core/nodes/transform/scatter_random_transform_node.gd"), preload("res://addons/scatter/editor/views/transform/scatter_random_transform_view.gd")],
	[preload("res://addons/scatter/core/nodes/transform/scatter_random_rotation_node.gd"), preload("res://addons/scatter/editor/views/transform/scatter_random_rotation_view.gd")],
	[preload("res://addons/scatter/core/nodes/transform/scatter_look_at_node.gd"), preload("res://addons/scatter/editor/views/transform/scatter_look_at_view.gd")],
	[preload("res://addons/scatter/core/nodes/transform/scatter_snap_node.gd"), preload("res://addons/scatter/editor/views/transform/scatter_snap_view.gd")],
	[preload("res://addons/scatter/core/nodes/transform/scatter_relax_node.gd"), preload("res://addons/scatter/editor/views/transform/scatter_relax_view.gd")],
	[preload("res://addons/scatter/core/nodes/transform/scatter_clusterize_node.gd"), preload("res://addons/scatter/editor/views/transform/scatter_clusterize_view.gd")],
	[preload("res://addons/scatter/core/nodes/transform/scatter_project_node.gd"), preload("res://addons/scatter/editor/views/transform/scatter_project_view.gd")],
	[preload("res://addons/scatter/core/nodes/filter/scatter_remove_outside_node.gd"), preload("res://addons/scatter/editor/views/filter/scatter_remove_outside_view.gd")],
	[preload("res://addons/scatter/core/nodes/filter/scatter_remove_random_node.gd"), preload("res://addons/scatter/editor/views/filter/scatter_remove_random_view.gd")],
	[preload("res://addons/scatter/core/nodes/data/scatter_proxy_node.gd"), preload("res://addons/scatter/editor/views/data/scatter_proxy_view.gd")],
	[preload("res://addons/scatter/core/nodes/data/scatter_random_color_node.gd"), preload("res://addons/scatter/editor/views/data/scatter_random_color_view.gd")],
	[preload("res://addons/scatter/core/nodes/data/scatter_random_custom_data_node.gd"), preload("res://addons/scatter/editor/views/data/scatter_random_custom_data_view.gd")],
]


static func register_all() -> void:
	for entry in ENTRIES:
		var node_script: Script = entry[0]
		var view_script: Script = entry[1]
		var prototype := node_script.new() as ScatterNode
		if ScatterNodeRegistry.create_node(prototype.get_type_id()) == null:
			ScatterNodeRegistry.register_node(node_script, view_script)
		else:
			ScatterNodeRegistry.register_view(prototype.get_type_id(), view_script)


static func unregister_all() -> void:
	for entry in ENTRIES:
		var prototype := (entry[0] as Script).new() as ScatterNode
		ScatterNodeRegistry.unregister_node(prototype.get_type_id())
