@icon("res://resources/editor_icons/resource.svg")
extends Resource
class_name RS_NavigationInitialState

## Initial state for navigation slice (UI navigation + overlays)
##
## Fields:
## - shell: Current UI shell ("main_menu", "gameplay", "endgame")
## - base_scene_id: Active base scene id (mirrors scene slice)
## - overlay_stack: Logical overlay stack (pause, settings overlays, etc.)
## - overlay_return_stack: Previous overlays for RETURN_TO_PREVIOUS_OVERLAY flows
## - active_menu_panel: Active panel within current shell (menu/main, pause/root, etc.)

@export var shell: StringName = StringName("main_menu")
@export var base_scene_id: StringName = StringName("main_menu")
@export var overlay_stack: Array[StringName] = []
@export var overlay_return_stack: Array[StringName] = []
@export var active_menu_panel: StringName = StringName("menu/main")

func to_dictionary() -> Dictionary:
	return {
		"shell": shell,
		"base_scene_id": base_scene_id,
		"overlay_stack": overlay_stack.duplicate(true),
		"overlay_return_stack": overlay_return_stack.duplicate(true),
		"active_menu_panel": active_menu_panel
	}
