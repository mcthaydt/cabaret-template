extends RefCounted
class_name U_InteractionConfigResolver

static func script_matches(resource: Resource, expected_script: Script) -> bool:
	if resource == null or expected_script == null:
		return false

	var script_obj := resource.get_script() as Script
	while script_obj != null:
		if script_obj == expected_script:
			return true
		script_obj = script_obj.get_base_script()

	return false

static func as_string_name(value: Variant, fallback: StringName = StringName("")) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return fallback

static func as_string(value: Variant, fallback: String = "") -> String:
	if value is String:
		return value
	if value is StringName:
		return String(value)
	return fallback

static func as_int(value: Variant, fallback: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	return fallback

static func as_float(value: Variant, fallback: float = 0.0) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	return fallback

static func as_bool(value: Variant, fallback: bool = false) -> bool:
	if value is bool:
		return value
	return fallback
