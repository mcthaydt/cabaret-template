class_name U_ResourceAccessHelpers

## Shared resource access helpers for scene director classes.


static func resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	return value if value != null else fallback


static func to_resource_array(value: Variant) -> Array[Resource]:
	var resources: Array[Resource] = []
	if value is Array:
		for item in value:
			if item is Resource:
				resources.append(item as Resource)
	return resources


static func to_float(value: Variant, fallback: float) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	return fallback


static func to_int(value: Variant, fallback: int) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	return fallback


static func to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName("")
