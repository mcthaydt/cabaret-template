extends RefCounted
class_name U_StateValidator

## State validation and normalization helper.
##
## Extracted as part of Phase 10B-5 (T139b) to separate validation concerns
## from persistence I/O. Handles scene references, spawn point validation,
## and state normalization after deserialization.
##
## Responsibilities:
##   - Normalize loaded state (scenes, spawn points, arrays)
##   - Validate scene and spawn references against registries
##   - Sanitize user-provided state data
##
## Usage:
##   U_StateValidator.normalize_loaded_state(state)
##   var valid_spawn := U_StateValidator.normalize_spawn_reference(value)

const U_SceneRegistry := preload("res://scripts/scene_management/u_scene_registry.gd")

const DEFAULT_SCENE_ID := StringName("gameplay_base")
const DEFAULT_SPAWN_POINT := StringName("sp_default")
const SPAWN_PREFIX := "sp_"
const CHECKPOINT_PREFIX := "cp_"

## Normalize all slices in loaded state.
##
## Validates scene references, spawn points, and arrays.
## Modifies state dictionary in-place.
static func normalize_loaded_state(state: Dictionary) -> void:
	if state.has("scene") and state["scene"] is Dictionary:
		_normalize_scene_slice(state["scene"])
	if state.has("gameplay") and state["gameplay"] is Dictionary:
		_normalize_gameplay_slice(state["gameplay"])

## Normalize scene slice references.
##
## Validates current_scene_id against scene registry.
## Falls back to DEFAULT_SCENE_ID if invalid.
static func _normalize_scene_slice(scene_slice: Dictionary) -> void:
	var raw_scene_id: Variant = scene_slice.get("current_scene_id", StringName(""))
	var scene_id := _as_string_name(raw_scene_id)

	if validate_scene_reference(scene_id):
		scene_slice["current_scene_id"] = scene_id
	else:
		if not String(scene_id).is_empty():
			push_warning(
				"State load: Unknown scene_id '%s'. Falling back to %s."
				% [String(scene_id), String(DEFAULT_SCENE_ID)]
			)
		scene_slice["current_scene_id"] = DEFAULT_SCENE_ID

## Normalize gameplay slice spawn references.
##
## Validates target_spawn_point and last_checkpoint.
## Deduplicates completed_areas array.
static func _normalize_gameplay_slice(gameplay_slice: Dictionary) -> void:
	gameplay_slice["target_spawn_point"] = normalize_spawn_reference(
		gameplay_slice.get("target_spawn_point", StringName("")),
		true
	)
	gameplay_slice["last_checkpoint"] = normalize_spawn_reference(
		gameplay_slice.get("last_checkpoint", StringName("")),
		true
	)

	var raw_completed: Variant = gameplay_slice.get("completed_areas", [])
	gameplay_slice["completed_areas"] = sanitize_completed_areas(raw_completed)

## Validate a scene reference against the scene registry.
##
## Returns true if the scene exists in U_SceneRegistry, false otherwise.
static func validate_scene_reference(scene_id: StringName) -> bool:
	if scene_id.is_empty():
		return false
	return not U_SceneRegistry.get_scene(scene_id).is_empty()

## Validate and normalize a spawn point reference.
##
## Checks for sp_ or cp_ prefix. Falls back to DEFAULT_SPAWN_POINT
## if invalid and emit_warning is true.
##
## Args:
##   value: The spawn point identifier (StringName, String, or other)
##   allow_empty: If true, empty strings are allowed (returns StringName(""))
##   emit_warning: If true, warns on invalid spawn points
##
## Returns: Normalized StringName spawn point reference
static func normalize_spawn_reference(
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

## Validate spawn point reference exists in a scene.
##
## Note: This requires scene-specific validation which is not currently
## implemented in the registry. For now, this checks prefix validity only.
##
## Returns true if spawn has valid prefix (sp_ or cp_)
static func validate_spawn_reference(spawn_id: StringName, _scene_id: StringName = StringName("")) -> bool:
	var text := String(spawn_id)
	if text.is_empty():
		return false
	return text.begins_with(SPAWN_PREFIX) or text.begins_with(CHECKPOINT_PREFIX)

## Sanitize and deduplicate completed_areas array.
##
## Filters out empty strings and duplicates.
## Returns Array[String] with unique identifiers.
static func sanitize_completed_areas(raw_completed: Variant) -> Array[String]:
	var completed: Array[String] = []

	if not raw_completed is Array:
		return completed

	for entry in (raw_completed as Array):
		var identifier := String(entry).strip_edges()
		if identifier.is_empty():
			continue
		if not completed.has(identifier):
			completed.append(identifier)

	return completed

## Convert variant to StringName safely.
##
## Handles StringName, String, and other types.
## Returns StringName("") for unsupported types.
static func _as_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName("")
