extends RefCounted
class_name U_StatePersistence

## State persistence helper for M_StateStore.
##
## Extracted as part of Phase 9C (T092a) to keep M_StateStore focused on
## store orchestration while this helper owns save/load I/O.
##
## Updated in Phase 10B-5 (T139b) to delegate validation/normalization
## to U_StateValidator for better separation of concerns.

const U_STATE_VALIDATOR := preload("res://scripts/state/utils/u_state_validator.gd")

## Save the given state dictionary to a JSON file.
##
## Excludes transient fields as defined in slice configs.
## Returns OK on success, or an Error code on failure.
static func save_state(filepath: String, state: Dictionary, slice_configs: Dictionary) -> Error:
	if filepath.is_empty():
		push_error("U_StatePersistence.save_state: Empty filepath")
		return ERR_INVALID_PARAMETER

	var state_to_save: Dictionary = {}
	for slice_name in state:
		var slice_state: Dictionary = state[slice_name]
		var config: RS_StateSliceConfig = slice_configs.get(slice_name)
		if config != null and config.is_transient:
			continue

		var filtered_state: Dictionary = {}
		if String(slice_name) == "gameplay":
			# Persist full gameplay slice including input fields for save/load.
			filtered_state = slice_state.duplicate(true)
		else:
			for key in slice_state:
				var is_transient: bool = false
				if config != null:
					is_transient = config.transient_fields.has(key)
				if not is_transient:
					filtered_state[key] = slice_state[key]

		state_to_save[slice_name] = U_SerializationHelper.godot_to_json(filtered_state)

	var json_string: String = JSON.stringify(state_to_save, "\t")

	var file: FileAccess = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		var error: Error = FileAccess.get_open_error()
		push_error("U_StatePersistence.save_state: Failed to open file for writing: ", error)
		return error

	file.store_string(json_string)
	file.close()

	return OK

## Load state from a JSON file and merge into the given state dictionary.
##
## Merges loaded state with current state, preserving transient fields
## according to slice configs. Returns OK on success, or an Error code on failure.
static func load_state(filepath: String, state: Dictionary, slice_configs: Dictionary) -> Error:
	if filepath.is_empty():
		push_error("U_StatePersistence.load_state: Empty filepath")
		return ERR_INVALID_PARAMETER

	if not FileAccess.file_exists(filepath):
		push_error("U_StatePersistence.load_state: File does not exist: ", filepath)
		return ERR_FILE_NOT_FOUND

	var file: FileAccess = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		var error: Error = FileAccess.get_open_error()
		push_error("U_StatePersistence.load_state: Failed to open file for reading: ", error)
		return error

	var json_string: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_string)
	if parsed == null or not parsed is Dictionary:
		push_error("U_StatePersistence.load_state: Invalid JSON in file")
		return ERR_PARSE_ERROR

	var loaded_state: Dictionary = parsed as Dictionary
	var deserialized_state: Dictionary = U_SerializationHelper.json_to_godot(loaded_state)

	U_STATE_VALIDATOR.normalize_loaded_state(deserialized_state)

	for slice_name in deserialized_state:
		if state.has(slice_name):
			var loaded_slice: Dictionary = deserialized_state[slice_name]
			var current_slice: Dictionary = state[slice_name]
			var config: RS_StateSliceConfig = slice_configs.get(slice_name)

			if config != null:
				for transient_field in config.transient_fields:
					if current_slice.has(transient_field) and not loaded_slice.has(transient_field):
						loaded_slice[transient_field] = current_slice[transient_field]

			state[slice_name] = loaded_slice.duplicate(true)

	return OK

## DEPRECATED: Use U_StateValidator.normalize_loaded_state() instead.
## Kept for backward compatibility with existing tests.
static func _normalize_loaded_state(state: Dictionary) -> void:
	U_STATE_VALIDATOR.normalize_loaded_state(state)

## DEPRECATED: Use U_StateValidator.normalize_spawn_reference() instead.
## Kept for backward compatibility with existing tests.
static func _normalize_spawn_reference(
	value: Variant,
	allow_empty: bool,
	emit_warning: bool = true
) -> StringName:
	return U_STATE_VALIDATOR.normalize_spawn_reference(value, allow_empty, emit_warning)
