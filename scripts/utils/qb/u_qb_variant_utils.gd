extends RefCounted
class_name U_QBVariantUtils

static func get_int_property(object_value: Variant, property_name: String, fallback: int) -> int:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = object_value.get(property_name)
	if value == null:
		return fallback
	return int(value)

static func get_bool_property(object_value: Variant, property_name: String, fallback: bool) -> bool:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = object_value.get(property_name)
	if value == null:
		return fallback
	if value is bool:
		return value
	return fallback

static func get_float_property(object_value: Variant, property_name: String, fallback: float) -> float:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = object_value.get(property_name)
	if value == null:
		return fallback
	if value is float or value is int:
		return float(value)
	return fallback

static func get_string_property(object_value: Variant, property_name: String, fallback: String) -> String:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = object_value.get(property_name)
	if value == null:
		return fallback
	if value is String:
		return value
	if value is StringName:
		return String(value)
	return fallback

static func get_array_property(object_value: Variant, property_name: String) -> Array:
	if object_value == null or not (object_value is Object):
		return []
	var value: Variant = object_value.get(property_name)
	if value is Array:
		return value as Array
	return []

static func object_has_property(object_value: Variant, property_name: String) -> bool:
	if object_value == null or not (object_value is Object):
		return false
	var object_data: Object = object_value as Object
	var properties: Array = object_data.get_property_list()
	for property_info_variant in properties:
		if not (property_info_variant is Dictionary):
			continue
		var property_info: Dictionary = property_info_variant as Dictionary
		var name_variant: Variant = property_info.get("name", "")
		if String(name_variant) == property_name:
			return true
	return false

static func get_dict(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, null)
	if value is Dictionary:
		return value as Dictionary
	var key_name: StringName = StringName(key)
	var key_name_value: Variant = source.get(key_name, null)
	if key_name_value is Dictionary:
		return key_name_value as Dictionary
	return {}

static func dict_get_string_or_name(dictionary: Dictionary, key: String) -> Variant:
	if dictionary.has(key):
		return dictionary.get(key)
	var key_name: StringName = StringName(key)
	if dictionary.has(key_name):
		return dictionary.get(key_name)
	return null
