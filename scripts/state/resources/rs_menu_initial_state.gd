extends Resource
class_name RS_MenuInitialState

## Initial state for menu slice
##
## Defines default values for menu/UI navigation state.
## Used by M_StateStore to initialize menu slice on _ready().

@export var active_screen: String = "main_menu"  ## Current menu screen

## Convert resource to Dictionary for state store
func to_dictionary() -> Dictionary:
	return {
		"active_screen": active_screen
	}
