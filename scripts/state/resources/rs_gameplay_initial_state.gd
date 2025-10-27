extends Resource
class_name RS_GameplayInitialState

## Initial state for gameplay slice
##
## Defines default values for gameplay state fields.
## Used by M_StateStore to initialize gameplay slice on _ready().

@export var paused: bool = false

## Convert resource to Dictionary for state store
func to_dictionary() -> Dictionary:
	return {
		"paused": paused
	}
