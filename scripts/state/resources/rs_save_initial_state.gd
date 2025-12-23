@icon("res://resources/editor_icons/resource.svg")
extends Resource
class_name RS_SaveInitialState

## Initial state for save management slice
##
## Defines default values for save state fields.
## Used by M_StateStore to initialize save slice on _ready().

# Operation state flags
@export var is_saving: bool = false
@export var is_loading: bool = false
@export var is_deleting: bool = false

# Last successful save slot (-1 = none)
@export var last_save_slot: int = -1

# UI mode (0 = SAVE, 1 = LOAD)
@export var current_mode: int = 1  # Default to LOAD mode

# Error tracking
@export var last_error: String = ""

## Convert resource to Dictionary for state store
func to_dictionary() -> Dictionary:
	return {
		"is_saving": is_saving,
		"is_loading": is_loading,
		"is_deleting": is_deleting,
		"last_save_slot": last_save_slot,
		"current_mode": current_mode,
		"last_error": last_error
	}
