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
		U_NavigationActions.ACTION_NAVIGATE_TO_UI_SCREEN:
			return _reduce_navigate_to_ui_screen(state, action)
		U_NavigationActions.ACTION_SET_SAVE_LOAD_MODE:
			return _reduce_set_save_load_mode(state, action)
		_:
			return state

static func get_close_mode_for_overlay(overlay_id: StringName) -> int:
	# Look up close_mode from UI registry; default to RESUME_TO_GAMEPLAY
	var definition: Dictionary = U_UIRegistry.get_screen(overlay_id)
	if not definition.is_empty():
		var mode_variant: Variant = definition.get("close_mode", CloseMode.RESUME_TO_GAMEPLAY)
		if mode_variant is int:
			return mode_variant
		return int(mode_variant)
	# Fallbacks for legacy/static overlays
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
	new_state["overlay_return_stack"] = []

	if target_shell == SHELL_MAIN_MENU:
		new_state["active_menu_panel"] = DEFAULT_MENU_PANEL
	elif target_shell == SHELL_GAMEPLAY:
		new_state["active_menu_panel"] = state.get("active_menu_panel", DEFAULT_PAUSE_PANEL)

	return new_state

static func _reduce_open_pause(state: Dictionary) -> Dictionary:
	var shell: StringName = state.get("shell", StringName())
	var current_stack: Array = state.get("overlay_stack", [])

	if shell != SHELL_GAMEPLAY or current_stack.size() > 0:
		return state

	var new_state: Dictionary = state.duplicate(true)
	new_state["overlay_stack"] = [OVERLAY_PAUSE]
	new_state["overlay_return_stack"] = []
	new_state["active_menu_panel"] = DEFAULT_PAUSE_PANEL
	return new_state

static func _reduce_close_pause(state: Dictionary) -> Dictionary:
	var shell: StringName = state.get("shell", StringName())
	if shell != SHELL_GAMEPLAY:
		return state

	var new_state: Dictionary = state.duplicate(true)
	new_state["overlay_stack"] = []
	new_state["overlay_return_stack"] = []
	return new_state

static func _reduce_open_overlay(state: Dictionary, action: Dictionary) -> Dictionary:
	var overlay_id: StringName = action.get("screen_id", StringName())
	var shell: StringName = state.get("shell", StringName())
	var current_stack: Array = state.get("overlay_stack", [])
	var return_stack: Array = state.get("overlay_return_stack", [])

	if overlay_id == StringName("") or shell != SHELL_GAMEPLAY:
		return state

	if overlay_id == OVERLAY_PAUSE:
		return state  # Pause opens via OPEN_PAUSE

	if not _is_overlay_allowed_for_parent(overlay_id, current_stack):
		return state

	var new_state: Dictionary = state.duplicate(true)
	var new_stack: Array = []
	var new_return_stack: Array = return_stack.duplicate(true)

	# Determine parent overlay (if any) for return navigation
	var parent_overlay: StringName = StringName("")
	if not current_stack.is_empty() and current_stack.back() is StringName:
		parent_overlay = current_stack.back()

	# Remember current top overlay (can be empty when opening first overlay)
	new_return_stack.append(parent_overlay)
	new_stack.append(overlay_id)

	new_state["overlay_stack"] = new_stack
	new_state["overlay_return_stack"] = new_return_stack
	return new_state

static func _reduce_close_top_overlay(state: Dictionary) -> Dictionary:
	var current_stack: Array = state.get("overlay_stack", [])
	var return_stack: Array = state.get("overlay_return_stack", [])
	if current_stack.is_empty():
		return state

	var top_overlay: StringName = current_stack.back()
	var close_mode: int = get_close_mode_for_overlay(top_overlay)
	var new_state: Dictionary = state.duplicate(true)

	match close_mode:
		CloseMode.RETURN_TO_PREVIOUS_OVERLAY:
			var new_stack: Array = []
			var new_return_stack: Array = return_stack.duplicate(true)
			var previous_overlay: StringName = StringName("")
			if not new_return_stack.is_empty():
				previous_overlay = new_return_stack.pop_back()
			if previous_overlay != StringName(""):
				new_stack.append(previous_overlay)
			new_state["overlay_stack"] = new_stack
			new_state["overlay_return_stack"] = new_return_stack
		CloseMode.RESUME_TO_GAMEPLAY:
			new_state["overlay_stack"] = []
			new_state["overlay_return_stack"] = []
		CloseMode.RESUME_TO_MENU:
			new_state["overlay_stack"] = []
			new_state["overlay_return_stack"] = []
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
	new_state["overlay_return_stack"] = []
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
	new_state["overlay_return_stack"] = []
	new_state["active_menu_panel"] = state.get("active_menu_panel", DEFAULT_MENU_PANEL)
	new_state["last_gameplay_scene_id"] = state.get("last_gameplay_scene_id", previous_gameplay_scene)
	# Clear any transition metadata when entering endgame; endgame flows
	# will provide their own per-action transition preferences.
	new_state.erase("_transition_metadata")
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
	new_state["overlay_return_stack"] = []
	new_state["active_menu_panel"] = DEFAULT_PAUSE_PANEL
	new_state["last_gameplay_scene_id"] = desired_scene
	# Retry transitions (from Game Over / Victory) should be snappy to keep
	# the flow responsive. Store transition metadata so M_SceneManager can
	# prefer instant, high-priority transitions for this navigation change.
	new_state["_transition_metadata"] = {
		"transition_type": "instant",
		"priority": 2
	}
	return new_state

static func _reduce_skip_to_credits(state: Dictionary) -> Dictionary:
	var new_state: Dictionary = state.duplicate(true)
	new_state["shell"] = SHELL_ENDGAME
	new_state["base_scene_id"] = StringName("credits")
	new_state["overlay_stack"] = []
	new_state["overlay_return_stack"] = []
	# Skipping to credits from Victory should avoid long fades so quick
	# checks and automated flows stay responsive.
	new_state["_transition_metadata"] = {
		"transition_type": "instant",
		"priority": 2
	}
	return new_state

static func _reduce_skip_to_menu(state: Dictionary) -> Dictionary:
	var new_state: Dictionary = state.duplicate(true)
	new_state["shell"] = SHELL_MAIN_MENU
	new_state["base_scene_id"] = SHELL_MAIN_MENU
	new_state["overlay_stack"] = []
	new_state["overlay_return_stack"] = []
	new_state["active_menu_panel"] = DEFAULT_MENU_PANEL
	# Credits auto-return to menu should be immediate; mark this navigation
	# change so Scene Manager uses an instant transition.
	new_state["_transition_metadata"] = {
		"transition_type": "instant",
		"priority": 2
	}
	return new_state

static func _reduce_return_to_main_menu(state: Dictionary) -> Dictionary:
	var new_state: Dictionary = state.duplicate(true)
	new_state["shell"] = SHELL_MAIN_MENU
	new_state["base_scene_id"] = SHELL_MAIN_MENU
	new_state["overlay_stack"] = []
	new_state["overlay_return_stack"] = []
	new_state["active_menu_panel"] = DEFAULT_MENU_PANEL
	# Game Over / Victory "Menu" button should feel instant. Flag this
	# navigation request so Scene Manager does not apply long fades.
	new_state["_transition_metadata"] = {
		"transition_type": "instant",
		"priority": 2
	}
	return new_state

static func _reduce_navigate_to_ui_screen(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_state: Dictionary = state.duplicate(true)
	var scene_id: StringName = action.get("scene_id", StringName(""))

	if scene_id == StringName(""):
		return state

	# Set the base_scene_id to trigger M_SceneManager reconciliation
	# The transition_type and priority are stored for M_SceneManager to use
	new_state["base_scene_id"] = scene_id
	new_state["_transition_metadata"] = {
		"transition_type": action.get("transition_type", "fade"),
		"priority": action.get("priority", 2)
	}

	return new_state

static func _reduce_set_save_load_mode(state: Dictionary, action: Dictionary) -> Dictionary:
	var mode: StringName = action.get("mode", StringName(""))
	if mode == StringName(""):
		return state

	var new_state: Dictionary = state.duplicate(true)
	new_state["save_load_mode"] = mode
	return new_state

static func _is_overlay_allowed_for_parent(overlay_id: StringName, current_stack: Array) -> bool:
	if current_stack.is_empty():
		return false

	var parent_overlay: StringName = current_stack.back() if current_stack.back() is StringName else StringName("")
	var is_valid := U_UIRegistry.is_valid_overlay_for_parent(overlay_id, parent_overlay)
	# Use UI registry to check allowed_parents
	return is_valid
