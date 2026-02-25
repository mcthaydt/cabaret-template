extends RefCounted
class_name U_PathResolver

static func resolve(root: Variant, path: String) -> Variant:
	if path.is_empty():
		return root

	var current: Variant = root
	var segments: PackedStringArray = path.split(".")
	for segment in segments:
		if segment.is_empty() or current == null:
			return null
		current = _resolve_segment(current, segment)
		if current == null:
			return null

	return current

static func _resolve_segment(current: Variant, segment: String) -> Variant:
	if current is Dictionary:
		return _resolve_dictionary_segment(current as Dictionary, segment)

	if current is Array:
		return _resolve_array_segment(current as Array, segment)

	if current is Object:
		return _resolve_object_segment(current as Object, segment)

	return null

static func _resolve_dictionary_segment(dictionary: Dictionary, segment: String) -> Variant:
	if dictionary.has(segment):
		return dictionary.get(segment)

	var segment_name: StringName = StringName(segment)
	if dictionary.has(segment_name):
		return dictionary.get(segment_name)

	return null

static func _resolve_array_segment(array_value: Array, segment: String) -> Variant:
	if not segment.is_valid_int():
		return null

	var index: int = int(segment)
	if index < 0 or index >= array_value.size():
		return null

	return array_value[index]

static func _resolve_object_segment(object_value: Object, segment: String) -> Variant:
	if not _object_has_property(object_value, segment):
		return null

	return object_value.get(segment)

static func _object_has_property(object_value: Object, property_name: String) -> bool:
	var properties: Array[Dictionary] = object_value.get_property_list()
	for property_info in properties:
		var name_value: Variant = property_info.get("name", "")
		if str(name_value) == property_name:
			return true
	return false
