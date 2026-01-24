@icon("res://assets/editor_icons/resource.svg")
extends Resource
class_name RS_BootInitialState

## Initial state for boot slice
##
## Defines default values for boot/initialization state fields.
## Used by M_StateStore to initialize boot slice on _ready().

@export var loading_progress: float = 0.0  ## Range 0.0-1.0
@export var phase: String = "loading"  ## Boot phase: "loading", "error", "ready"
@export var error_message: String = ""  ## Error message if boot fails
@export var is_ready: bool = false  ## True when boot sequence complete

## Convert resource to Dictionary for state store
func to_dictionary() -> Dictionary:
	return {
		"loading_progress": loading_progress,
		"phase": phase,
		"error_message": error_message,
		"is_ready": is_ready
	}
