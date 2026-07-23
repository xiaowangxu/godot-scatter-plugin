@tool
class_name ScatterEditorSettings
extends RefCounted

const BUILD_INSTANCE_LIMIT := &"scatter/limits/build_instance_limit"
const PREVIEW_INSTANCE_LIMIT := &"scatter/limits/preview_instance_limit"
const GIZMO_INSTANCE_LIMIT := &"scatter/limits/gizmo_instance_limit"

const DEFAULT_BUILD_INSTANCE_LIMIT := 1_000_000
const DEFAULT_PREVIEW_INSTANCE_LIMIT := 2_000
const DEFAULT_GIZMO_INSTANCE_LIMIT := 2_000

const LIMIT_HINT := "1,100000000,1,or_greater"


static func register_settings() -> void:
	_register_limit(BUILD_INSTANCE_LIMIT, DEFAULT_BUILD_INSTANCE_LIMIT)
	_register_limit(PREVIEW_INSTANCE_LIMIT, DEFAULT_PREVIEW_INSTANCE_LIMIT)
	_register_limit(GIZMO_INSTANCE_LIMIT, DEFAULT_GIZMO_INSTANCE_LIMIT)


static func build_instance_limit() -> int:
	return _limit(BUILD_INSTANCE_LIMIT, DEFAULT_BUILD_INSTANCE_LIMIT)


static func preview_instance_limit() -> int:
	return _limit(PREVIEW_INSTANCE_LIMIT, DEFAULT_PREVIEW_INSTANCE_LIMIT)


static func gizmo_instance_limit() -> int:
	return _limit(GIZMO_INSTANCE_LIMIT, DEFAULT_GIZMO_INSTANCE_LIMIT)


static func _register_limit(setting: StringName, default_value: int) -> void:
	var settings := EditorInterface.get_editor_settings()
	if not settings.has_setting(setting):
		settings.set_setting(setting, default_value)
	settings.set_initial_value(setting, default_value, false)
	settings.add_property_info({
		"name": setting,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": LIMIT_HINT,
	})


static func _limit(setting: StringName, fallback: int) -> int:
	if not Engine.is_editor_hint():
		return fallback
	return maxi(1, int(EditorInterface.get_editor_settings().get_setting(setting)))
