extends RefCounted
class_name U_NavigationReducer

## Reducer for navigation slice
##
## Handles UI shells, overlay stack, and menu panel selection.

const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_SceneRegistry := preload("res://scripts/scene_management/u_scene_registry.gd")
const U_UIRegistry := preload("res://scripts/ui/u_ui_registry.gd")

enum CloseMode {
	RETURN_TO_PREVIOUS_OVERLAY = 0,
	RESUME_TO_GAMEPLAY = 1,
	RESUME_TO_MENU = 2
}

const SHELL_MAIN_MENU := StringName("main_menu")
const SHELL_GAMEPLAY := StringName("gameplay")
const SHELL_ENDGAME := StringName("endgame")

const OVERLAY_PAUSE := StringName("pause_menu")
const OVERLAY_SETTINGS := StringName("settings_menu_overlay")
const OVERLAY_INPUT_PROFILE := StringName("input_profile_selector")
const OVERLAY_GAMEPAD_SETTINGS := StringName("gamepad_settings")
const OVERLAY_TOUCHSCREEN_SETTINGS := StringName("touchscreen_settings")
const OVERLAY_INPUT_REBINDING := StringName("input_rebinding")
const OVERLAY_EDIT_TOUCH_CONTROLS := StringName("edit_touch_controls")

const DEFAULT_MENU_PANEL := StringName("menu/main")
const DEFAULT_PAUSE_PANEL := StringName("pause/root")
const DEFAULT_RETRY_SCENE := StringName("exterior")

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	var action_type: StringName = action.get("type", StringName())

	match action_type:
		U_NavigationActions.ACTION_SET_SHELL:
			return _reduce_set_shell(state, action)
		U_NavigationActions.ACTION_OPEN_PAUSE:
			return _reduce_open_pause(state)
		U_NavigationActions.ACTION_CLOSE_PAUSE:
			return _reduce_close_pause(state)
		U_NavigationActions.ACTION_OPEN_OVERLAY:
			return _reduce_open_overlay(state, action)
		U_NavigationActions.ACTION_CLOSE_TOP_OVERLAY:
			return _reduce_close_top_overlay(state)
		U_NavigationActions.ACTION_SET_MENU_PANEL:
			return _reduce_set_menu_panel(state, action)
		U_NavigationActions.ACTION_START_GAME:
			return _reduce_start_game(state, action)
		U_NavigationActions.ACTION_OPEN_ENDGAME:
			return _reduce_open_endgame(state, action)
		U_NavigationActions.ACTION_RETRY:
			return _reduce_retry(state, action)
		U_NavigationActions.ACTION_SKIP_TO_CREDITS:
			return _reduce_skip_to_credits(state)
		U_NavigationActions.ACTION_SKIP_TO_MENU:
			return _reduce_skip_to_menu(state)
		U_NavigationActions.ACTION_RETURN_TO_MAIN_MENU:
			return _reduce_return_to_main_menu(state)
		_:
			return state

static func get_close_mode_for_overlay(overlay_id: StringName) -> int:
	if overlay_id == OVERLAY_SETTINGS:
		return CloseMode.RETURN_TO_PREVIOUS_OVERLAY
	if overlay_id == OVERLAY_PAUSE:
		return CloseMode.RESUME_TO_GAMEPLAY
	return CloseMode.RESUME_TO_GAMEPLAY

static func _reduce_set_shell(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_state: Dictionary = state.duplicate(true)
	var target_shell: StringName = action.get("shell", SHELL_MAIN_MENU)
	var target_scene: StringName = action.get("base_scene_id", state.get("base_scene_id", SHELL_MAIN_MENU))

	new_state["shell"] = target_shell
	new_state["base_scene_id"] = target_scene
	new_state["overlay_stack"] = []

	if target_shell == SHELL_MAIN_MENU:
		new_state["active_menu_panel"] = DEFAULT_MENU_PANEL
	elif target_shell == SHELL_GAMEPLAY:
		new_state["active_menu_panel"] = state.get("active_menu_panel", DEFAULT_PAUSE_PANEL)

	return new_state

static func _reduce_open_pause(state: Dictionary) -> Dictionary:
	var shell: StringName = state.get("shell", StringName())
	var current_stack: Array = state.get("overlay_stack", [])

	print("[DIAG-REDUCER] _reduce_open_pause ENTRY")
	print("[DIAG-REDUCER]   shell=", shell, " (need: gameplay)")
	print("[DIAG-REDUCER]   current_stack=", current_stack, " (need: empty)")

	if shell != SHELL_GAMEPLAY or current_stack.size() > 0:
		print("[DIAG-REDUCER]   REJECTED: shell != gameplay OR stack not empty")
		print("[DIAG-REDUCER]     shell == SHELL_GAMEPLAY? ", shell == SHELL_GAMEPLAY)
		print("[DIAG-REDUCER]     stack.size() = ", current_stack.size())
		return state

	var new_state: Dictionary = state.duplicate(true)
	new_state["overlay_stack"] = [OVERLAY_PAUSE]
	new_state["active_menu_panel"] = DEFAULT_PAUSE_PANEL
	print("[DIAG-REDUCER]   ACCEPTED: new overlay_stack=[pause_menu]")
	return new_state

static func _reduce_close_pause(state: Dictionary) -> Dictionary:
	var shell: StringName = state.get("shell", StringName())
	if shell != SHELL_GAMEPLAY:
		return state

	var new_state: Dictionary = state.duplicate(true)
	new_state["overlay_stack"] = []
	return new_state

static func _reduce_open_overlay(state: Dictionary, action: Dictionary) -> Dictionary:
	var overlay_id: StringName = action.get("screen_id", StringName())
	var shell: StringName = state.get("shell", StringName())
	var current_stack: Array = state.get("overlay_stack", [])

	print("[DIAG-REDUCER] _reduce_open_overlay ENTRY")
	print("[DIAG-REDUCER]   overlay_id=", overlay_id)
	print("[DIAG-REDUCER]   shell=", shell)
	print("[DIAG-REDUCER]   current_stack=", current_stack)

	if overlay_id == StringName("") or shell != SHELL_GAMEPLAY:
		print("[DIAG-REDUCER]   REJECTED: empty overlay_id or shell != gameplay")
		return state

	if overlay_id == OVERLAY_PAUSE:
		print("[DIAG-REDUCER]   REJECTED: pause uses OPEN_PAUSE action")
		return state  # Pause opens via OPEN_PAUSE

	if not _is_overlay_allowed_for_parent(overlay_id, current_stack):
		print("[DIAG-REDUCER]   REJECTED: parent validation failed")
		return state

	if current_stack.has(overlay_id):
		print("[DIAG-REDUCER]   REJECTED: overlay already in stack")
		return state

	var new_state: Dictionary = state.duplicate(true)
	var new_stack: Array = current_stack.duplicate(true)
	new_stack.append(overlay_id)
	new_state["overlay_stack"] = new_stack
	print("[DIAG-REDUCER]   ACCEPTED: new_stack=", new_stack)
	return new_state

static func _reduce_close_top_overlay(state: Dictionary) -> Dictionary:
	var current_stack: Array = state.get("overlay_stack", [])
	if current_stack.is_empty():
		return state

	var top_overlay: StringName = current_stack.back()
	var close_mode: int = get_close_mode_for_overlay(top_overlay)
	var new_state: Dictionary = state.duplicate(true)

	match close_mode:
		CloseMode.RETURN_TO_PREVIOUS_OVERLAY:
			var new_stack: Array = current_stack.duplicate(true)
			new_stack.pop_back()
			new_state["overlay_stack"] = new_stack
		CloseMode.RESUME_TO_GAMEPLAY:
			new_state["overlay_stack"] = []
		CloseMode.RESUME_TO_MENU:
			new_state["overlay_stack"] = []
			new_state["shell"] = SHELL_MAIN_MENU
			new_state["base_scene_id"] = SHELL_MAIN_MENU

	return new_state

static func _reduce_set_menu_panel(state: Dictionary, action: Dictionary) -> Dictionary:
	var panel_id: StringName = action.get("panel_id", StringName())
	if panel_id == StringName(""):
		return state

	var new_state: Dictionary = state.duplicate(true)
	new_state["active_menu_panel"] = panel_id
	return new_state

static func _reduce_start_game(state: Dictionary, action: Dictionary) -> Dictionary:
	var scene_id: StringName = action.get("scene_id", state.get("base_scene_id", DEFAULT_RETRY_SCENE))
	if scene_id == StringName(""):
		scene_id = DEFAULT_RETRY_SCENE

	var new_state: Dictionary = state.duplicate(true)
	new_state["shell"] = SHELL_GAMEPLAY
	new_state["base_scene_id"] = scene_id
	new_state["overlay_stack"] = []
	new_state["active_menu_panel"] = DEFAULT_PAUSE_PANEL
	new_state["last_gameplay_scene_id"] = scene_id
	return new_state

static func _reduce_open_endgame(state: Dictionary, action: Dictionary) -> Dictionary:
	var scene_id: StringName = action.get("scene_id", StringName("game_over"))
	var previous_gameplay_scene: StringName = state.get("base_scene_id", DEFAULT_RETRY_SCENE)

	var new_state: Dictionary = state.duplicate(true)
	new_state["shell"] = SHELL_ENDGAME
	new_state["base_scene_id"] = scene_id
	new_state["overlay_stack"] = []
	new_state["active_menu_panel"] = state.get("active_menu_panel", DEFAULT_MENU_PANEL)
	new_state["last_gameplay_scene_id"] = state.get("last_gameplay_scene_id", previous_gameplay_scene)
	return new_state

static func _reduce_retry(state: Dictionary, action: Dictionary) -> Dictionary:
	var desired_scene: StringName = action.get("scene_id", StringName())
	if desired_scene == StringName(""):
		desired_scene = state.get("last_gameplay_scene_id", state.get("base_scene_id", DEFAULT_RETRY_SCENE))
	if desired_scene == StringName(""):
		desired_scene = DEFAULT_RETRY_SCENE

	var scene_data: Dictionary = U_SceneRegistry.get_scene(desired_scene)
	var scene_type: int = scene_data.get("scene_type", U_SceneRegistry.SceneType.GAMEPLAY)
	if scene_type != U_SceneRegistry.SceneType.GAMEPLAY:
		desired_scene = DEFAULT_RETRY_SCENE

	var new_state: Dictionary = state.duplicate(true)
	new_state["shell"] = SHELL_GAMEPLAY
	new_state["base_scene_id"] = desired_scene
	new_state["overlay_stack"] = []
	new_state["active_menu_panel"] = DEFAULT_PAUSE_PANEL
	new_state["last_gameplay_scene_id"] = desired_scene
	return new_state

static func _reduce_skip_to_credits(state: Dictionary) -> Dictionary:
	var new_state: Dictionary = state.duplicate(true)
	new_state["shell"] = SHELL_ENDGAME
	new_state["base_scene_id"] = StringName("credits")
	new_state["overlay_stack"] = []
	return new_state

static func _reduce_skip_to_menu(state: Dictionary) -> Dictionary:
	var new_state: Dictionary = state.duplicate(true)
	new_state["shell"] = SHELL_MAIN_MENU
	new_state["base_scene_id"] = SHELL_MAIN_MENU
	new_state["overlay_stack"] = []
	new_state["active_menu_panel"] = DEFAULT_MENU_PANEL
	return new_state

static func _reduce_return_to_main_menu(state: Dictionary) -> Dictionary:
	var new_state: Dictionary = state.duplicate(true)
	new_state["shell"] = SHELL_MAIN_MENU
	new_state["base_scene_id"] = SHELL_MAIN_MENU
	new_state["overlay_stack"] = []
	new_state["active_menu_panel"] = DEFAULT_MENU_PANEL
	return new_state

static func _is_overlay_allowed_for_parent(overlay_id: StringName, current_stack: Array) -> bool:
	print("[DIAG-VALID] overlay_id=", overlay_id, " current_stack=", current_stack)

	if current_stack.is_empty():
		print("[DIAG-VALID] REJECTED: stack is EMPTY")
		return false

	var parent_overlay: StringName = current_stack.back() if current_stack.back() is StringName else StringName("")
	var is_valid := U_UIRegistry.is_valid_overlay_for_parent(overlay_id, parent_overlay)
	print("[DIAG-VALID] parent=", parent_overlay, " is_valid=", is_valid)

	# Use UI registry to check allowed_parents
	return is_valid
