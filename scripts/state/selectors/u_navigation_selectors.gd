extends RefCounted
class_name U_NavigationSelectors

## Selectors for navigation slice
##
## Provide derived answers for UI shell, overlays, and panels.


static func get_shell(state: Dictionary) -> StringName:
	return state.get("shell", StringName())

static func get_base_scene_id(state: Dictionary) -> StringName:
	return state.get("base_scene_id", StringName())

static func get_overlay_stack(state: Dictionary) -> Array:
	var stack: Variant = state.get("overlay_stack", [])
	if stack is Array:
		return (stack as Array).duplicate(true)
	return []

static func get_top_overlay_id(state: Dictionary) -> StringName:
	var stack: Array = get_overlay_stack(state)
	if stack.is_empty():
		return StringName("")
	return stack.back()

static func is_paused(state: Dictionary) -> bool:
	return get_shell(state) == U_NavigationReducer.SHELL_GAMEPLAY and get_overlay_stack(state).size() > 0

static func get_active_menu_panel(state: Dictionary) -> StringName:
	return state.get("active_menu_panel", StringName())

static func get_top_overlay_close_mode(state: Dictionary) -> int:
	var top_overlay: StringName = get_top_overlay_id(state)
	if top_overlay == StringName(""):
		return U_NavigationReducer.CloseMode.RESUME_TO_GAMEPLAY
	return U_NavigationReducer.get_close_mode_for_overlay(top_overlay)

static func is_in_endgame(state: Dictionary) -> bool:
	return get_shell(state) == U_NavigationReducer.SHELL_ENDGAME
