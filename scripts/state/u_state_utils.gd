@icon("res://editor_icons/utility.svg")
extends RefCounted
class_name U_StateUtils

## Safely duplicates a value, handling all Godot types correctly.
##
## Dictionaries and Arrays are deep-copied by default to ensure immutability.
## Primitives (int, float, bool, String, StringName, null) are returned as-is
## since they are value types in GDScript.
##
## @param value: The value to duplicate
## @param deep: Whether to perform deep copy (default: true)
## @return: A deep copy for Dictionaries/Arrays, or the value itself for primitives
static func safe_duplicate(value: Variant, deep: bool = true) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY, TYPE_ARRAY:
			return value.duplicate(deep)
		_:
			return value
