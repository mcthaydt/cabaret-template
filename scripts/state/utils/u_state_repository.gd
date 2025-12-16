extends RefCounted
class_name U_StateRepository

## State persistence repository for M_StateStore.
##
## Extracted as part of Phase 10B-5 (T139a) to centralize persistence
## coordination, auto-save logic, and path resolution while delegating
## actual I/O to U_StatePersistence.
##
## Responsibilities:
##   - High-level save/load coordination
##   - Auto-save lifecycle management
##   - Save path resolution
##   - Auto-load at startup
##
## Usage:
##   var err := U_StateRepository.save_state(filepath, state, slice_configs)
##   var should_save := U_StateRepository.should_autosave(settings)

const U_STATE_PERSISTENCE := preload("res://scripts/state/utils/u_state_persistence.gd")
const U_STATE_VALIDATOR := preload("res://scripts/state/utils/u_state_validator.gd")

## Save the current state to a JSON file.
##
## Delegates to U_StatePersistence for actual I/O after validation.
## Excludes transient fields as defined in slice configs.
## Returns OK on success, or an Error code on failure.
static func save_state(filepath: String, state: Dictionary, slice_configs: Dictionary) -> Error:
	if filepath.is_empty():
		push_error("U_StateRepository.save_state: Empty filepath")
		return ERR_INVALID_PARAMETER

	return U_STATE_PERSISTENCE.save_state(filepath, state, slice_configs)

## Load state from a JSON file.
##
## Delegates to U_StatePersistence for I/O and U_StateValidator for normalization.
## Merges loaded state with current state, preserving transient fields.
## Returns OK on success, or an Error code on failure.
static func load_state(filepath: String, state: Dictionary, slice_configs: Dictionary) -> Error:
	if filepath.is_empty():
		push_error("U_StateRepository.load_state: Empty filepath")
		return ERR_INVALID_PARAMETER

	return U_STATE_PERSISTENCE.load_state(filepath, state, slice_configs)

## Check if auto-save is enabled in settings.
##
## Returns true if persistence is enabled, false otherwise.
static func should_autosave(settings: RS_StateStoreSettings) -> bool:
	if settings == null:
		return false
	return settings.enable_persistence

## Get the save file path from settings.
##
## Returns the override path if set, otherwise returns default user:// path.
static func get_save_path(settings: RS_StateStoreSettings) -> String:
	if settings != null:
		var override_path := String(settings.save_path_override)
		if not override_path.is_empty():
			return override_path
	return "user://savegame.json"

## Try to auto-load state at startup.
##
## Checks if persistence is enabled and file exists before loading.
## Returns true if state was loaded, false otherwise.
static func try_autoload_state(
	settings: RS_StateStoreSettings,
	state: Dictionary,
	slice_configs: Dictionary,
	enable_debug_logging: bool = false
) -> bool:
	if not should_autosave(settings):
		return false

	var path := get_save_path(settings)
	if not FileAccess.file_exists(path):
		return false

	var err: Error = load_state(path, state, slice_configs)
	if err != OK:
		if OS.is_debug_build() and enable_debug_logging:
			push_warning("U_StateRepository: Autoload failed (", err, ") from ", path)
		return false

	return true

## Save state if persistence is enabled.
##
## Convenience method for auto-save and shutdown scenarios.
## Returns OK if saved successfully, error code otherwise.
static func save_state_if_enabled(
	settings: RS_StateStoreSettings,
	state: Dictionary,
	slice_configs: Dictionary,
	enable_debug_logging: bool = false
) -> Error:
	if not should_autosave(settings):
		return ERR_SKIP

	var path := get_save_path(settings)
	var err: Error = save_state(path, state, slice_configs)

	if err != OK and OS.is_debug_build() and enable_debug_logging:
		push_warning("U_StateRepository: Save failed (", err, ") to ", path)

	return err

## Get the auto-save interval from settings.
##
## Returns the interval in seconds, or 0.0 if auto-save is disabled.
static func get_autosave_interval(settings: RS_StateStoreSettings) -> float:
	if not should_autosave(settings):
		return 0.0

	if settings.auto_save_interval <= 0.0:
		return 0.0

	return max(settings.auto_save_interval, 0.0)
