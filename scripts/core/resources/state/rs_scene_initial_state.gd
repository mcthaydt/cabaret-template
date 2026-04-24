@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_SceneInitialState

## Initial state for scene management slice
##
## Defines default values for scene state fields.
## Used by M_StateStore to initialize scene slice on _ready().
##
## State Fields:
## - current_scene_id: Active scene identifier
## - scene_stack: TRANSIENT - Array of overlay scenes (pause, settings, etc.)
## - is_transitioning: TRANSIENT - transition in progress flag
## - transition_type: TRANSIENT - Current transition effect type (instant, fade, loading)
## - previous_scene_id: Scene we transitioned from (for history/back navigation)

# Current active scene
@export var current_scene_id: StringName = StringName("")

# Overlay scene stack (for pause menus, settings overlays, etc.)
# Bottom of stack = first overlay, top = most recent
@export var scene_stack: Array[StringName] = []

# Transition state (TRANSIENT - not persisted to save files)
@export var is_transitioning: bool = false
@export var transition_type: String = ""

# Scene history
@export var previous_scene_id: StringName = StringName("")

## Convert resource to Dictionary for state store
func to_dictionary() -> Dictionary:
	return {
		"current_scene_id": current_scene_id,
		"scene_stack": scene_stack.duplicate(true),
		"is_transitioning": is_transitioning,
		"transition_type": transition_type,
		"previous_scene_id": previous_scene_id
	}
