@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_UIScreenDefinition

## Resource defining a UI screen/overlay/panel entry for the UI registry.
##
## Fields:
## - screen_id: Unique ID used by navigation and selectors
## - kind: UIScreenKind enum (BASE_SCENE, OVERLAY, PANEL)
## - scene_id: Scene registry id backing this screen (required for BASE_SCENE/OVERLAY)
## - allowed_shells: Shells where this screen is valid (e.g., ["gameplay"])
## - allowed_parents: Valid parent overlays (empty = top-level overlay)
## - close_mode: CloseMode enum driving overlay close behavior
## - hides_previous_overlays: If true, hide all overlays underneath this one (for transparent overlays that need clear view)

const U_SceneRegistry := preload("res://scripts/scene_management/u_scene_registry.gd")

enum UIScreenKind {
	BASE_SCENE = 0,
	OVERLAY = 1,
	PANEL = 2
}

enum CloseMode {
	RETURN_TO_PREVIOUS_OVERLAY = 0,
	RESUME_TO_GAMEPLAY = 1,
	RESUME_TO_MENU = 2
}

@export var screen_id: StringName = StringName("")
@export var kind: int = UIScreenKind.BASE_SCENE
@export var scene_id: StringName = StringName("")
@export var allowed_shells: Array[StringName] = []
@export var allowed_parents: Array[StringName] = []
@export var close_mode: int = CloseMode.RESUME_TO_GAMEPLAY
@export var hides_previous_overlays: bool = false

## Validate resource configuration for registry usage.
func validate() -> bool:
	var is_valid: bool = true

	if screen_id == StringName(""):
		push_error("RS_UIScreenDefinition: screen_id is required")
		is_valid = false

	if kind < UIScreenKind.BASE_SCENE or kind > UIScreenKind.PANEL:
		push_error("RS_UIScreenDefinition: kind is out of range for %s" % screen_id)
		is_valid = false

	if allowed_shells.is_empty():
		push_error("RS_UIScreenDefinition: allowed_shells cannot be empty for %s" % screen_id)
		is_valid = false

	if close_mode < CloseMode.RETURN_TO_PREVIOUS_OVERLAY or close_mode > CloseMode.RESUME_TO_MENU:
		push_error("RS_UIScreenDefinition: close_mode is invalid for %s" % screen_id)
		is_valid = false

	if kind != UIScreenKind.PANEL:
		if scene_id == StringName(""):
			push_error("RS_UIScreenDefinition: scene_id is required for %s" % screen_id)
			is_valid = false
		elif U_SceneRegistry.get_scene(scene_id).is_empty():
			push_error("RS_UIScreenDefinition: scene_id %s is not registered" % scene_id)
			is_valid = false

	return is_valid

## Convert to dictionary (defensive copy).
func to_dictionary() -> Dictionary:
	return {
		"screen_id": screen_id,
		"kind": kind,
		"scene_id": scene_id,
		"allowed_shells": allowed_shells.duplicate(true),
		"allowed_parents": allowed_parents.duplicate(true),
		"close_mode": close_mode,
		"hides_previous_overlays": hides_previous_overlays
	}
