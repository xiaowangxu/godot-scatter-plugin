@tool
class_name ScatterSchema
extends RefCounted

const REGION_PORT_TYPE := 1
const PLACEMENT_PORT_TYPE := 2
const SCATTER_SET_PORT_TYPE := 3
const REGION_COLOR := Color("55b8a6")
const PLACEMENT_COLOR := Color("b889e8")
const SCATTER_SET_COLOR := Color("e1a85a")

const CATEGORIES := {
	"集合 Group": [&"group"],
	"区域 Region": [&"shape_box", &"shape_sphere", &"shape_path", &"paint_region", &"region_union", &"region_intersection", &"region_subtract"],
	"布点 Placement": [&"create_random", &"create_grid", &"create_poisson", &"edge_random", &"edge_even", &"edge_continuous", &"single", &"placement_merge"],
	"变换 Transform": [&"array", &"transform", &"position", &"rotation", &"scale", &"random_transform", &"random_rotation", &"look_at", &"snap", &"relax", &"clusterize", &"project"],
	"过滤 Filter": [&"remove_outside", &"remove_random"],
	"数据 Data": [&"proxy", &"random_color", &"random_custom_data"],
}

static var DEFINITIONS := {
	# `output` is retained only so v2 recipes can be loaded and migrated.
	"output": {"title": "Legacy Output", "color": Color("d9aa56"), "params": {}},
	"group": {"title": "Scatter Group", "color": Color("c48745"), "params": {}},
	"final_output": {"title": "Final Output", "color": Color("d9aa56"), "params": {}},
	"paint_region": {"title": "Paint Region", "color": Color("3fae9a"), "params": {
		"strokes": {"type": "paint_data", "default": [], "hidden": true},
		"depth": {"type": "float", "default": 0.35, "min": 0.01, "max": 1000.0, "step": 0.05},
		"surface_offset": {"type": "float", "default": 0.0, "min": -1000.0, "max": 1000.0, "step": 0.01},
	}},
	"region_union": {"title": "Union", "color": Color("3fae9a"), "params": {}},
	"region_intersection": {"title": "Intersection", "color": Color("3fae9a"), "params": {}},
	"region_subtract": {"title": "Subtract", "color": Color("3fae9a"), "params": {}},
	"placement_merge": {"title": "Merge Placement", "color": Color("9b70c9"), "params": {}},
	"shape_box": {"title": "Box Domain", "color": Color("5d83b3"), "params": {
		"center": {"type": "vector3", "default": Vector3.ZERO},
		"size": {"type": "vector3", "default": Vector3(10, 1, 10)},
		"rotation": {"type": "vector3", "default": Vector3.ZERO},
		"negative": {"type": "bool", "default": false, "hidden": true},
	}},
	"shape_sphere": {"title": "Sphere Domain", "color": Color("5d83b3"), "params": {
		"center": {"type": "vector3", "default": Vector3.ZERO},
		"radius": {"type": "float", "default": 5.0, "min": 0.001, "step": 0.1},
		"negative": {"type": "bool", "default": false, "hidden": true},
	}},
	"shape_path": {"title": "Path Domain", "color": Color("5d83b3"), "params": {
		"points": {"type": "path", "default": PackedVector3Array([Vector3(-5, 0, 0), Vector3(5, 0, 0)])},
		"thickness": {"type": "float", "default": 1.0, "min": 0.0, "step": 0.1},
		"closed": {"type": "bool", "default": false},
		"negative": {"type": "bool", "default": false, "hidden": true},
	}},
	"create_random": {"title": "Create Random", "color": Color("4b9b72"), "params": {
		"amount": {"type": "int", "default": 100, "min": 0, "max": 1000000},
		"restrict_height": {"type": "bool", "default": true},
	}},
	"create_grid": {"title": "Create Grid", "color": Color("4b9b72"), "params": {
		"spacing": {"type": "vector3", "default": Vector3(2, 2, 2)},
		"restrict_height": {"type": "bool", "default": true},
	}},
	"create_poisson": {"title": "Create Poisson", "color": Color("4b9b72"), "params": {
		"radius": {"type": "float", "default": 1.0, "min": 0.001, "step": 0.05},
		"samples_before_rejection": {"type": "int", "default": 15, "min": 1, "max": 100},
		"max_points": {"type": "int", "default": 10000, "min": 1, "max": 1000000},
		"restrict_height": {"type": "bool", "default": true},
	}},
	"edge_random": {"title": "Along Edge Random", "color": Color("4b9b72"), "params": {
		"instance_count": {"type": "int", "default": 10, "min": 0, "max": 1000000},
		"align_to_path": {"type": "bool", "default": false},
	}},
	"edge_even": {"title": "Along Edge Even", "color": Color("4b9b72"), "params": {
		"spacing": {"type": "float", "default": 1.0, "min": 0.001, "step": 0.1},
		"offset": {"type": "float", "default": 0.0, "step": 0.1},
		"align_to_path": {"type": "bool", "default": false},
	}},
	"edge_continuous": {"title": "Along Edge Continuous", "color": Color("4b9b72"), "params": {
		"item_length": {"type": "float", "default": 2.0, "min": 0.001, "step": 0.1},
		"ignore_slopes": {"type": "bool", "default": false},
	}},
	"single": {"title": "Add Single Item", "color": Color("4b9b72"), "params": {
		"offset": {"type": "vector3", "default": Vector3.ZERO},
		"rotation": {"type": "vector3", "default": Vector3.ZERO},
		"scale": {"type": "vector3", "default": Vector3.ONE},
	}},
	"array": {"title": "Array", "color": Color("4b9b72"), "params": {
		"amount": {"type": "int", "default": 1, "min": 1, "max": 10000},
		"min_amount": {"type": "int", "default": -1, "min": -1, "max": 10000},
		"local_offset": {"type": "bool", "default": false},
		"offset": {"type": "vector3", "default": Vector3(2, 0, 0)},
		"local_rotation": {"type": "bool", "default": false},
		"rotation": {"type": "vector3", "default": Vector3.ZERO},
		"individual_rotation_pivots": {"type": "bool", "default": true},
		"rotation_pivot": {"type": "vector3", "default": Vector3.ZERO},
		"local_scale": {"type": "bool", "default": true},
		"scale": {"type": "vector3", "default": Vector3.ONE},
		"randomize_indices": {"type": "bool", "default": true},
	}},
	"transform": {"title": "Edit Transform", "color": Color("a376bc"), "params": {
		"position": {"type": "vector3", "default": Vector3.ZERO},
		"rotation": {"type": "vector3", "default": Vector3.ZERO},
		"scale": {"type": "vector3", "default": Vector3.ONE},
		"space": {"type": "enum", "default": 2, "items": ["Global", "Local", "Instance"]},
	}},
	"position": {"title": "Edit Position", "color": Color("a376bc"), "params": {
		"operation": {"type": "enum", "default": 0, "items": ["Offset", "Multiply", "Override"]},
		"position": {"type": "vector3", "default": Vector3.ZERO},
		"space": {"type": "enum", "default": 1, "items": ["Global", "Local", "Instance"]},
	}},
	"rotation": {"title": "Edit Rotation", "color": Color("a376bc"), "params": {
		"operation": {"type": "enum", "default": 0, "items": ["Offset", "Multiply", "Override"]},
		"rotation": {"type": "vector3", "default": Vector3.ZERO},
		"space": {"type": "enum", "default": 2, "items": ["Global", "Local", "Instance"]},
	}},
	"scale": {"title": "Edit Scale", "color": Color("a376bc"), "params": {
		"operation": {"type": "enum", "default": 1, "items": ["Offset", "Multiply", "Override"]},
		"scale": {"type": "vector3", "default": Vector3.ONE},
		"space": {"type": "enum", "default": 2, "items": ["Global", "Local", "Instance"]},
	}},
	"random_transform": {"title": "Randomize Transforms", "color": Color("a376bc"), "params": {
		"position": {"type": "vector3", "default": Vector3.ZERO},
		"rotation": {"type": "vector3", "default": Vector3.ZERO},
		"scale": {"type": "vector3", "default": Vector3.ZERO},
		"space": {"type": "enum", "default": 2, "items": ["Global", "Local", "Instance"]},
	}},
	"random_rotation": {"title": "Randomize Rotation", "color": Color("a376bc"), "params": {
		"rotation": {"type": "vector3", "default": Vector3(0, 360, 0)},
		"snap_angle": {"type": "vector3", "default": Vector3.ZERO},
		"space": {"type": "enum", "default": 2, "items": ["Global", "Local", "Instance"]},
	}},
	"look_at": {"title": "Look At", "color": Color("a376bc"), "params": {
		"target": {"type": "vector3", "default": Vector3.ZERO},
		"up": {"type": "vector3", "default": Vector3.UP},
	}},
	"snap": {"title": "Snap Transforms", "color": Color("a376bc"), "params": {
		"position_step": {"type": "vector3", "default": Vector3.ZERO},
		"rotation_step": {"type": "vector3", "default": Vector3.ZERO},
		"scale_step": {"type": "vector3", "default": Vector3.ZERO},
	}},
	"relax": {"title": "Relax Position", "color": Color("a376bc"), "params": {
		"iterations": {"type": "int", "default": 3, "min": 1, "max": 100},
		"offset_step": {"type": "float", "default": 0.01, "min": 0.0, "step": 0.01},
		"consecutive_step_multiplier": {"type": "float", "default": 0.5, "min": 0.0, "step": 0.05},
		"restrict_height": {"type": "bool", "default": true},
	}},
	"clusterize": {"title": "Clusterize by Mask", "color": Color("a376bc"), "params": {
		"mask": {"type": "file", "default": ""},
		"mask_rotation": {"type": "float", "default": 0.0, "step": 1.0},
		"mask_offset": {"type": "vector2", "default": Vector2.ZERO},
		"mask_scale": {"type": "vector2", "default": Vector2.ONE},
		"pixel_to_unit_ratio": {"type": "float", "default": 64.0, "min": 0.001, "step": 1.0},
		"remove_below": {"type": "float", "default": 0.1, "min": 0.0, "max": 1.0, "step": 0.01},
		"remove_above": {"type": "float", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		"scale_transforms": {"type": "bool", "default": true},
	}},
	"project": {"title": "Project On Colliders", "color": Color("a376bc"), "params": {
		"ray_direction": {"type": "vector3", "default": Vector3.DOWN},
		"ray_length": {"type": "float", "default": 10.0, "min": 0.0, "step": 0.1},
		"ray_offset": {"type": "float", "default": 1.0, "step": 0.1},
		"remove_points_on_miss": {"type": "bool", "default": true},
		"align_with_collision_normal": {"type": "bool", "default": false},
		"max_slope": {"type": "float", "default": 90.0, "min": 0.0, "max": 90.0, "step": 1.0},
		"collision_mask": {"type": "int", "default": 1, "min": 0, "max": 4294967295},
		"exclude_mask": {"type": "int", "default": 0, "min": 0, "max": 4294967295},
	}},
	"remove_outside": {"title": "Remove Outside", "color": Color("bd5b60"), "params": {
		"negative_shapes_only": {"type": "bool", "default": false},
	}},
	"remove_random": {"title": "Remove Random", "color": Color("bd5b60"), "params": {
		"probability": {"type": "float", "default": 50.0, "min": 0.0, "max": 100.0, "step": 1.0},
	}},
	"proxy": {"title": "Proxy Recipe", "color": Color("8b929e"), "params": {
		"scatter_node": {"type": "node_path", "default": NodePath()},
		"auto_rebuild": {"type": "bool", "default": true},
	}},
	"random_color": {"title": "Random Color", "color": Color("8b929e"), "params": {
		"from": {"type": "color", "default": Color.WHITE},
		"to": {"type": "color", "default": Color.WHITE},
	}},
	"random_custom_data": {"title": "Random Custom Data", "color": Color("8b929e"), "params": {
		"from": {"type": "color", "default": Color(0, 0, 0, 0)},
		"to": {"type": "color", "default": Color(1, 1, 1, 1)},
	}},
}


static func definition(type: StringName) -> Dictionary:
	return DEFINITIONS.get(String(type), {})


static func defaults_for(type: StringName) -> Dictionary:
	var result := {}
	var def := definition(type)
	for key in def.get("params", {}):
		result[key] = def.params[key].get("default")
	return result


static func is_shape(type: StringName) -> bool:
	return String(type).begins_with("shape_")


static func is_region_source(type: StringName) -> bool:
	return is_shape(type) or String(type) == "paint_region"


static func is_region_operator(type: StringName) -> bool:
	return String(type) in ["region_union", "region_intersection", "region_subtract"]


static func is_region(type: StringName) -> bool:
	return is_region_source(type) or is_region_operator(type)


static func is_placement_source(type: StringName) -> bool:
	return String(type) in ["create_random", "create_grid", "create_poisson", "edge_random", "edge_even", "edge_continuous", "single", "proxy"]


static func is_placement(type: StringName) -> bool:
	var value := String(type)
	return value not in ["output", "group", "final_output"] and not is_region(value) and DEFINITIONS.has(value)


static func is_group(type: StringName) -> bool:
	return String(type) == "group"


static func is_final_output(type: StringName) -> bool:
	return String(type) == "final_output"


static func uses_seed(type: StringName) -> bool:
	return String(type) in [
		"create_random", "create_poisson", "edge_random", "array",
		"random_transform", "random_rotation", "remove_random",
		"random_color", "random_custom_data",
	]


static func display_title(type: StringName) -> String:
	return TITLES_ZH.get(String(type), definition(type).get("title", String(type)))


static func description(type: StringName) -> String:
	return DESCRIPTIONS_ZH.get(String(type), "连接节点来定义散布数据流。")


static func parameter_label(key: StringName) -> String:
	return PARAMETER_LABELS_ZH.get(String(key), String(key).capitalize())


static func parameter_tooltip(key: StringName) -> String:
	return PARAMETER_TOOLTIPS_ZH.get(String(key), "修改此节点的 %s 参数。" % parameter_label(key))


const TITLES_ZH := {
	"output": "散布组",
	"group": "散布组",
	"final_output": "最终输出",
	"shape_box": "盒形区域",
	"shape_sphere": "球形区域",
	"shape_path": "路径区域",
	"paint_region": "绘制区域",
	"region_union": "区域合并",
	"region_intersection": "区域相交",
	"region_subtract": "区域相减",
	"create_random": "随机布点",
	"create_grid": "网格布点",
	"create_poisson": "泊松布点",
	"edge_random": "边缘随机",
	"edge_even": "边缘等距",
	"edge_continuous": "边缘连续",
	"single": "单点",
	"placement_merge": "合并布点",
	"array": "阵列",
	"transform": "变换",
	"position": "位置",
	"rotation": "旋转",
	"scale": "缩放",
	"random_transform": "随机变换",
	"random_rotation": "随机旋转",
	"look_at": "朝向目标",
	"snap": "步进吸附",
	"relax": "松弛",
	"clusterize": "纹理聚类",
	"project": "投射到表面",
	"remove_outside": "移除区域外",
	"remove_random": "随机移除",
	"proxy": "引用配方",
	"random_color": "随机颜色",
	"random_custom_data": "随机自定义数据",
}

const DESCRIPTIONS_ZH := {
	"output": "旧版输出节点；打开时会自动迁移为散布组。",
	"group": "组合一个区域与一条布点流，输出一个 Scatter Set。",
	"final_output": "聚合任意数量的 Scatter Set，并写入当前 MultiMesh。",
	"shape_box": "一个可旋转的盒形体积区域。",
	"shape_sphere": "一个球形体积区域。",
	"shape_path": "沿折线路径生成具有厚度的区域，也可用于边缘布点。",
	"paint_region": "在 3D 视口表面绘制区域。每个绘制节点保存独立图层，可与其它区域组合。",
	"region_union": "A 或 B 中的任意位置都属于结果区域。",
	"region_intersection": "只有同时位于 A 与 B 中的位置才属于结果区域。",
	"region_subtract": "从区域 A 中扣除区域 B。",
	"create_random": "在所属散布组的区域中随机生成指定数量的点。",
	"create_grid": "在所属散布组的区域中生成规则三维或平面网格。",
	"create_poisson": "生成彼此保持最小距离的自然分布点。",
	"placement_merge": "合并两条 Placement 分支。",
	"project": "使用物理射线把实例投射到碰撞表面。",
	"remove_outside": "移除不属于所属散布组区域的实例。",
}

const PARAMETER_LABELS_ZH := {
	"center": "中心", "size": "尺寸", "rotation": "旋转", "negative": "负区域（旧版）",
	"radius": "半径", "points": "路径点", "thickness": "厚度", "closed": "闭合",
	"depth": "绘制厚度", "surface_offset": "表面偏移", "amount": "数量", "min_amount": "最少数量",
	"restrict_height": "限制为平面", "spacing": "间距", "samples_before_rejection": "拒绝前尝试数",
	"max_points": "最大点数", "instance_count": "实例数量", "align_to_path": "沿路径对齐",
	"offset": "偏移", "item_length": "物体长度", "ignore_slopes": "忽略坡度", "scale": "缩放",
	"local_offset": "局部偏移", "local_rotation": "局部旋转", "individual_rotation_pivots": "独立旋转轴心",
	"rotation_pivot": "旋转轴心", "local_scale": "局部缩放", "randomize_indices": "随机阵列数量",
	"position": "位置", "space": "坐标空间", "operation": "运算", "snap_angle": "角度步进",
	"target": "目标", "up": "上方向", "position_step": "位置步进", "rotation_step": "旋转步进",
	"scale_step": "缩放步进", "iterations": "迭代次数", "offset_step": "位移步长",
	"consecutive_step_multiplier": "连续步长倍率", "mask": "遮罩纹理", "mask_rotation": "遮罩旋转",
	"mask_offset": "遮罩偏移", "mask_scale": "遮罩缩放", "pixel_to_unit_ratio": "像素单位比例",
	"remove_below": "移除低于", "remove_above": "移除高于", "scale_transforms": "按遮罩缩放",
	"ray_direction": "射线方向", "ray_length": "射线长度", "ray_offset": "射线起点偏移",
	"remove_points_on_miss": "移除未命中", "align_with_collision_normal": "对齐表面法线", "max_slope": "最大坡度",
	"collision_mask": "碰撞层", "exclude_mask": "排除层", "negative_shapes_only": "仅检查扣除区域",
	"probability": "概率", "scatter_node": "目标节点", "auto_rebuild": "跟随重建", "from": "起始值", "to": "结束值",
}

const PARAMETER_TOOLTIPS_ZH := {
	"depth": "绘制区域沿表面法线方向的有效厚度；相交/相减时会使用它。",
	"surface_offset": "生成点沿绘制时记录的表面法线偏移的距离。",
	"restrict_height": "启用后仅在区域中心高度布点，适合地面散布。",
	"collision_mask": "物理查询使用的 32 位碰撞层遮罩。",
	"override_seed": "为这个节点使用独立固定种子，不受全局种子改变影响。",
}
