class_name U_SaveValidator
extends RefCounted

## Save Validator Utility (Phase 8)
##
## Provides comprehensive validation for save file structure and content.
## Returns detailed error codes for different validation failures.
##
## Validation contract:
## - All validation methods are static
## - Returns Dictionary with either:
##   - Success: {"valid": true, "header": Dictionary, "state": Dictionary, "scene_id": StringName}
##   - Failure: {"valid": false, "error": Error, "message": String}

## Validate a loaded save file structure
##
## Checks:
## - Save data is not empty
## - Has required "header" and "state" keys
## - Header and state are Dictionaries
## - Header contains required fields (current_scene_id)
## - current_scene_id is not empty
##
## Returns Dictionary with validation result
static func validate_save_structure(save_data: Dictionary) -> Dictionary:
	# Check if save_data is empty
	if save_data.is_empty():
		return {
			"valid": false,
			"error": ERR_FILE_CORRUPT,
			"message": "Save file is empty or failed to load"
		}

	# Check for required top-level keys
	if not save_data.has("header"):
		return {
			"valid": false,
			"error": ERR_FILE_CORRUPT,
			"message": "Save file missing 'header' key"
		}

	if not save_data.has("state"):
		return {
			"valid": false,
			"error": ERR_FILE_CORRUPT,
			"message": "Save file missing 'state' key"
		}

	# Validate header is a Dictionary (untyped access to avoid runtime error)
	var header: Variant = save_data["header"]
	if not header is Dictionary:
		return {
			"valid": false,
			"error": ERR_FILE_CORRUPT,
			"message": "Save file 'header' is not a Dictionary (got %s)" % typeof(header)
		}

	# Validate state is a Dictionary
	var loaded_state: Variant = save_data["state"]
	if not loaded_state is Dictionary:
		return {
			"valid": false,
			"error": ERR_FILE_CORRUPT,
			"message": "Save file 'state' is not a Dictionary (got %s)" % typeof(loaded_state)
		}

	# Validate header contents
	var header_dict := header as Dictionary
	var validation_result: Dictionary = validate_header_contents(header_dict)
	if not validation_result["valid"]:
		return validation_result

	# Extract scene_id from header
	var scene_id: StringName = StringName(header_dict.get("current_scene_id", ""))

	# Return success with validated data
	return {
		"valid": true,
		"header": header_dict,
		"state": loaded_state as Dictionary,
		"scene_id": scene_id
	}

## Validate header contents (required fields and types)
##
## Checks:
## - Has current_scene_id field
## - current_scene_id is not empty
##
## Future: Could validate other fields (save_version type, timestamp format, etc.)
static func validate_header_contents(header: Dictionary) -> Dictionary:
	# Validate current_scene_id exists
	if not header.has("current_scene_id"):
		return {
			"valid": false,
			"error": ERR_FILE_CORRUPT,
			"message": "Save file header missing 'current_scene_id'"
		}

	# Validate current_scene_id is not empty
	var scene_id: String = str(header.get("current_scene_id", ""))
	if scene_id.is_empty():
		return {
			"valid": false,
			"error": ERR_FILE_CORRUPT,
			"message": "Save file 'current_scene_id' is empty"
		}

	# All validations passed
	return {"valid": true}

## Validate state contents (optional, for future use)
##
## Currently just checks state structure.
## Future: Could validate slice presence, types, etc.
static func validate_state_contents(state: Dictionary) -> Dictionary:
	# Basic validation - state should be a non-empty Dictionary
	# Individual slices are optional (empty state is technically valid)
	return {"valid": true}
