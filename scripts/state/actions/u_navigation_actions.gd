extends RefCounted
class_name U_NavigationActions

## Action creators for navigation slice
##
## Navigation actions drive UI shells, overlays, and panel selection.

const ACTION_SET_SHELL := StringName("navigation/set_shell")
const ACTION_OPEN_PAUSE := StringName("navigation/open_pause")
const ACTION_CLOSE_PAUSE := StringName("navigation/close_pause")
const ACTION_OPEN_OVERLAY := StringName("navigation/open_overlay")
const ACTION_CLOSE_TOP_OVERLAY := StringName("navigation/close_top_overlay")
const ACTION_SET_MENU_PANEL := StringName("navigation/set_menu_panel")
const ACTION_START_GAME := StringName("navigation/start_game")
const ACTION_OPEN_ENDGAME := StringName("navigation/open_endgame")
const ACTION_RETRY := StringName("navigation/retry")
const ACTION_SKIP_TO_CREDITS := StringName("navigation/skip_to_credits")
const ACTION_SKIP_TO_MENU := StringName("navigation/skip_to_menu")
const ACTION_RETURN_TO_MAIN_MENU := StringName("navigation/return_to_main_menu")
const ACTION_NAVIGATE_TO_UI_SCREEN := StringName("navigation/navigate_to_ui_screen")
const ACTION_SET_SAVE_LOAD_MODE := StringName("navigation/set_save_load_mode")

## Register all navigation actions with the ActionRegistry
static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_SET_SHELL, {
		"required_root_fields": ["shell", "base_scene_id"]
	})
	U_ActionRegistry.register_action(ACTION_OPEN_PAUSE)
	U_ActionRegistry.register_action(ACTION_CLOSE_PAUSE)
	U_ActionRegistry.register_action(ACTION_OPEN_OVERLAY, {
		"required_root_fields": ["screen_id"]
	})
	U_ActionRegistry.register_action(ACTION_CLOSE_TOP_OVERLAY)
	U_ActionRegistry.register_action(ACTION_SET_MENU_PANEL, {
		"required_root_fields": ["panel_id"]
	})
	U_ActionRegistry.register_action(ACTION_START_GAME)
	U_ActionRegistry.register_action(ACTION_OPEN_ENDGAME)
	U_ActionRegistry.register_action(ACTION_RETRY)
	U_ActionRegistry.register_action(ACTION_SKIP_TO_CREDITS)
	U_ActionRegistry.register_action(ACTION_SKIP_TO_MENU)
	U_ActionRegistry.register_action(ACTION_RETURN_TO_MAIN_MENU)
	U_ActionRegistry.register_action(ACTION_NAVIGATE_TO_UI_SCREEN, {
		"required_root_fields": ["scene_id"]
	})
	U_ActionRegistry.register_action(ACTION_SET_SAVE_LOAD_MODE, {
		"required_root_fields": ["mode"]
	})

static func set_shell(shell: StringName, base_scene_id: StringName) -> Dictionary:
	return {
		"type": ACTION_SET_SHELL,
		"shell": shell,
		"base_scene_id": base_scene_id
	}

static func open_pause() -> Dictionary:
	return {
		"type": ACTION_OPEN_PAUSE
	}

static func close_pause() -> Dictionary:
	return {
		"type": ACTION_CLOSE_PAUSE
	}

static func open_overlay(screen_id: StringName) -> Dictionary:
	return {
		"type": ACTION_OPEN_OVERLAY,
		"screen_id": screen_id
	}

static func close_top_overlay() -> Dictionary:
	return {
		"type": ACTION_CLOSE_TOP_OVERLAY,
		# UI overlay closure needs same-frame visibility so SceneManager can
		# reconcile the UIOverlayStack immediately (even while paused).
		"immediate": true
	}

static func set_menu_panel(panel_id: StringName) -> Dictionary:
	return {
		"type": ACTION_SET_MENU_PANEL,
		"panel_id": panel_id
	}

static func start_game(scene_id: StringName) -> Dictionary:
	return {
		"type": ACTION_START_GAME,
		"scene_id": scene_id
	}

static func open_endgame(scene_id: StringName) -> Dictionary:
	return {
		"type": ACTION_OPEN_ENDGAME,
		"scene_id": scene_id
	}

static func retry(scene_id: StringName = StringName()) -> Dictionary:
	return {
		"type": ACTION_RETRY,
		"scene_id": scene_id
	}

static func skip_to_credits() -> Dictionary:
	return {
		"type": ACTION_SKIP_TO_CREDITS
	}

static func skip_to_menu() -> Dictionary:
	return {
		"type": ACTION_SKIP_TO_MENU
	}

static func return_to_main_menu() -> Dictionary:
	return {
		"type": ACTION_RETURN_TO_MAIN_MENU
	}

## Navigate to a standalone UI screen (used for settings screens in main menu context)
##
## This action triggers M_SceneManager to transition to the specified UI scene.
## Use this instead of calling M_SceneManager.transition_to_scene() directly from UI scripts.
##
## Payload:
## - scene_id: StringName - The scene ID to navigate to
## - transition_type: String - Transition effect ("fade", "instant", "loading")
## - priority: int - Transition priority (use M_SceneManager.Priority constants)
static func navigate_to_ui_screen(scene_id: StringName, transition_type: String = "fade", priority: int = 2) -> Dictionary:
	return {
		"type": ACTION_NAVIGATE_TO_UI_SCREEN,
		"scene_id": scene_id,
		"transition_type": transition_type,
		"priority": priority
	}

## Set the save/load mode for the combined save/load overlay
##
## Payload:
## - mode: StringName - Either "save" or "load"
static func set_save_load_mode(mode: StringName) -> Dictionary:
	return {
		"type": ACTION_SET_SAVE_LOAD_MODE,
		"mode": mode
	}
