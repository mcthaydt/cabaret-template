@icon("res://editor_icons/utility.svg")
extends RefCounted
class_name U_StatePersistence

const STATE_UTILS := preload("res://scripts/state/u_state_utils.gd")

const SAVE_VERSION := 1
const CHECKSUM_KEY := "checksum"
const VERSION_KEY := "version"
const DATA_KEY := "data"

static func serialize_state(state: Dictionary, persistable_slices: Array[StringName]) -> String:
	var filtered: Dictionary = {}
	for slice_name in persistable_slices:
		if state.has(slice_name):
			filtered[slice_name] = STATE_UTILS.safe_duplicate(state[slice_name])

	var checksum_seed: String = _build_checksum_seed(SAVE_VERSION, filtered)
	var checksum: int = hash(checksum_seed)

	var wrapped: Dictionary = {
		CHECKSUM_KEY: checksum,
		VERSION_KEY: SAVE_VERSION,
		DATA_KEY: filtered,
	}
	return JSON.stringify(wrapped)

static func deserialize_state(json_str: String) -> Dictionary:
	if json_str.is_empty():
		return {}

	var parsed_variant: Variant = JSON.parse_string(json_str)
	if typeof(parsed_variant) != TYPE_DICTIONARY:
		push_error("State Persistence: Invalid save data format")
		return {}

	var parsed: Dictionary = parsed_variant

	for key in [CHECKSUM_KEY, VERSION_KEY, DATA_KEY]:
		if !parsed.has(key):
			push_error("State Persistence: Missing %s field" % key)
			return {}

	var version: int = int(parsed[VERSION_KEY])
	var data_variant: Variant = parsed[DATA_KEY]
	var checksum: int = int(parsed[CHECKSUM_KEY])

	if typeof(data_variant) != TYPE_DICTIONARY:
		push_error("State Persistence: Data section must be a Dictionary")
		return {}

	var data: Dictionary = data_variant

	var checksum_seed: String = _build_checksum_seed(version, data)
	var expected_checksum: int = hash(checksum_seed)
	if checksum != expected_checksum:
		print("State Persistence: Checksum mismatch")
		return {}

	return STATE_UTILS.safe_duplicate(data)

static func save_to_file(path: String, state: Dictionary, persistable_slices: Array[StringName]) -> Error:
	var serialized: String = serialize_state(state, persistable_slices)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(serialized)
	file.close()
	return OK

static func load_from_file(path: String) -> Dictionary:
	if !FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var contents: String = file.get_as_text()
	file.close()
	return deserialize_state(contents)

static func _build_checksum_seed(version: int, data: Dictionary) -> String:
	return "%s|%s" % [str(version), _normalize_variant(data)]

static func _normalize_variant(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			var lookup: Dictionary = {}
			var key_strings: Array[String] = []
			for key in dict.keys():
				var key_string := str(key)
				key_strings.append(key_string)
				lookup[key_string] = dict[key]
			key_strings.sort()
			var builder: String = "{"
			for index in range(key_strings.size()):
				var key_string := key_strings[index]
				var normalized_value := _normalize_variant(lookup[key_string])
				if index > 0:
					builder += ","
				builder += "%s:%s" % [key_string, normalized_value]
			return builder + "}"
		TYPE_ARRAY:
			var array: Array = value
			var builder: String = "["
			for index in range(array.size()):
				if index > 0:
					builder += ","
				var element: Variant = array[index]
				builder += _normalize_variant(element)
			return builder + "]"
		TYPE_STRING_NAME, TYPE_STRING:
			return "\"%s\"" % str(value)
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_NIL:
			return "null"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			var int_value := int(value)
			if is_equal_approx(value, int_value):
				return str(int_value)
			return str(value)
		_:
			return JSON.stringify(value)
