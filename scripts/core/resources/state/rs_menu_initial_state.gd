@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_MenuInitialState

## Initial state for menu slice
##
## Defines default values for menu/UI navigation state.
## Used by M_StateStore to initialize menu slice on _ready().

@export var active_screen: String = "main_menu"  ## Current menu screen
@export var pending_character: String = ""  ## Selected character (before starting game)
@export var pending_difficulty: String = ""  ## Selected difficulty (before starting game)
@export var available_saves: Array = []  ## List of available save files

## Convert resource to Dictionary for state store
func to_dictionary() -> Dictionary:
	return {
		"active_screen": active_screen,
		"pending_character": pending_character,
		"pending_difficulty": pending_difficulty,
		"available_saves": available_saves.duplicate()
	}
