extends RefCounted
class_name U_StatePersistence

## State persistence and normalization helper for M_StateStore.
##
## Extracted as part of Phase 9C (T092a) to keep M_StateStore focused on
## store orchestration while this helper owns save/load and normalization.

const DEFAULT_SCENE_ID := StringName("gameplay_base")
const DEFAULT_SPAWN_POINT := StringName("sp_default")
const SPAWN_PREFIX := "sp_"
const CHECKPOINT_PREFIX := "cp_"

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

	_normalize_loaded_state(deserialized_state)

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

## Normalize scene and gameplay slices after deserialization.
static func _normalize_loaded_state(state: Dictionary) -> void:
	if state.has("scene") and state["scene"] is Dictionary:
		_normalize_scene_slice(state["scene"])
	if state.has("gameplay") and state["gameplay"] is Dictionary:
		_normalize_gameplay_slice(state["gameplay"])

static func _normalize_scene_slice(scene_slice: Dictionary) -> void:
	var raw_scene_id: Variant = scene_slice.get("current_scene_id", StringName(""))
	var scene_id := _as_string_name(raw_scene_id)
	if _is_scene_registered(scene_id):
		scene_slice["current_scene_id"] = scene_id
	else:
		if not String(scene_id).is_empty():
			push_warning(
				"State load: Unknown scene_id '%s'. Falling back to %s."
				% [String(scene_id), String(DEFAULT_SCENE_ID)]
			)
		scene_slice["current_scene_id"] = DEFAULT_SCENE_ID

static func _normalize_gameplay_slice(gameplay_slice: Dictionary) -> void:
	gameplay_slice["target_spawn_point"] = _normalize_spawn_reference(
		gameplay_slice.get("target_spawn_point", StringName("")),
		true
	)
	gameplay_slice["last_checkpoint"] = _normalize_spawn_reference(
		gameplay_slice.get("last_checkpoint", StringName("")),
		true
	)

	var raw_completed: Variant = gameplay_slice.get("completed_areas", [])
	var completed: Array[String] = []
	if raw_completed is Array:
		for entry in (raw_completed as Array):
			var identifier := String(entry).strip_edges()
			if identifier.is_empty():
				continue
			if not completed.has(identifier):
				completed.append(identifier)
	gameplay_slice["completed_areas"] = completed

static func _normalize_spawn_reference(
	value: Variant,
	allow_empty: bool,
	emit_warning: bool = true
) -> StringName:
	var spawn := _as_string_name(value)
	var text := String(spawn)
	if text.is_empty():
		return StringName("") if allow_empty else DEFAULT_SPAWN_POINT
	if text.begins_with(SPAWN_PREFIX):
		return spawn
	if text.begins_with(CHECKPOINT_PREFIX):
		return spawn
	if emit_warning:
		push_warning(
			"State load: Unknown spawn point '%s'. Using %s."
			% [text, String(DEFAULT_SPAWN_POINT)]
		)
	return DEFAULT_SPAWN_POINT

static func _as_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName("")

static func _is_scene_registered(scene_id: StringName) -> bool:
	if scene_id.is_empty():
		return false
	return not U_SceneRegistry.get_scene(scene_id).is_empty()
