@icon("res://resources/editor_icons/manager.svg")
extends Node
class_name M_UIInputHandler

## Thin UI input handler for context-based navigation routing
##
## Listens to ui_* actions and dispatches navigation actions based on current
## shell, overlay stack, and panel state. Does NOT hardcode physical keys or
## maintain separate navigation state.

const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_NavigationReducer := preload("res://scripts/state/reducers/u_navigation_reducer.gd")

var _store: I_StateStore = null

func _is_debug_logging_enabled() -> bool:
	if _store == null:
		return false
	# M_StateStore exposes `settings.enable_debug_logging`; allow missing in tests/mocks.
	var settings_variant: Variant = null
	if _store.has_method("get"):
		settings_variant = _store.get("settings")
	if settings_variant != null and settings_variant is Resource:
		var enabled: Variant = (settings_variant as Resource).get("enable_debug_logging")
		return bool(enabled)
	return false

func _debug(msg: String) -> void:
	if not _is_debug_logging_enabled():
		return
	if not OS.is_debug_build():
		return
	print("M_UIInputHandler: ", msg)


func _ready() -> void:
	# Run in PROCESS_MODE_ALWAYS to handle pause/unpause
	process_mode = PROCESS_MODE_ALWAYS

	# Wait for store to be ready
	await get_tree().process_frame
	_store = U_StateUtils.get_store(self)

	if _store == null:
		push_error("M_UIInputHandler: Failed to find M_StateStore")

func _input(event: InputEvent) -> void:
	if not _is_debug_logging_enabled():
		return
	if not OS.is_debug_build():
		return
	if _store == null:
		return

	var is_pressed_event: bool = false
	var event_desc: String = ""
	if event is InputEventKey:
		var key_event := event as InputEventKey
		is_pressed_event = key_event.pressed and not key_event.echo
		event_desc = "keycode=%d physical=%d" % [int(key_event.keycode), int(key_event.physical_keycode)]
	elif event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		is_pressed_event = joy_event.pressed
		event_desc = "joy_device=%d button_index=%d" % [int(joy_event.device), int(joy_event.button_index)]
	else:
		return

	if not is_pressed_event:
		return

	var matched_actions: Array[StringName] = []
	for action_name in [StringName("ui_pause"), StringName("ui_accept"), StringName("ui_cancel")]:
		if event.is_action_pressed(String(action_name)):
			matched_actions.append(action_name)
	if matched_actions.is_empty():
		return

	var state: Dictionary = _store.get_state()
	var nav_state: Dictionary = state.get("navigation", {})
	var shell: StringName = U_NavigationSelectors.get_shell(nav_state)
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_state)
	var focus_owner: Control = null
	var viewport := get_viewport()
	if viewport != null:
		focus_owner = viewport.gui_get_focus_owner() as Control
	var focus_path: String = String(focus_owner.get_path()) if focus_owner != null else "<none>"

	_debug("Input %s actions=%s shell=%s overlays=%d focus=%s" % [
		event_desc,
		str(matched_actions),
		String(shell),
		overlay_stack.size(),
		focus_path
	])

func _unhandled_input(event: InputEvent) -> void:
	if _store == null:
		return

	# Handle ui_pause (Start button - opens pause menu)
	if event.is_action_pressed("ui_pause"):
		_handle_ui_pause()
		get_viewport().set_input_as_handled()
		return

	# Handle ui_cancel (B button - back/cancel in menus only)
	if event.is_action_pressed("ui_cancel"):
		_handle_ui_cancel()
		get_viewport().set_input_as_handled()


## Handle ui_pause input (Start button - opens pause menu)
func _handle_ui_pause() -> void:
	var state: Dictionary = _store.get_state()
	var nav_state: Dictionary = state.get("navigation", {})

	var shell: StringName = U_NavigationSelectors.get_shell(nav_state)
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_state)

	# ui_pause only works in gameplay shell
	if shell == U_NavigationReducer.SHELL_GAMEPLAY:
		if overlay_stack.is_empty():
			# No overlays → open pause
			_store.dispatch(U_NavigationActions.open_pause())
		# If overlays already open, do nothing (ui_cancel handles closing them)

## Handle ui_cancel input (B button - back/cancel in menus only)
func _handle_ui_cancel() -> void:
	var state: Dictionary = _store.get_state()
	var nav_state: Dictionary = state.get("navigation", {})

	var shell: StringName = U_NavigationSelectors.get_shell(nav_state)
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_state)
	var active_panel: StringName = U_NavigationSelectors.get_active_menu_panel(nav_state)
	var base_scene_id: StringName = U_NavigationSelectors.get_base_scene_id(nav_state)

	# Context matrix per flows-and-input.md section 3.2
	match shell:
		U_NavigationReducer.SHELL_GAMEPLAY:
			_handle_gameplay_cancel(overlay_stack)

		U_NavigationReducer.SHELL_MAIN_MENU:
			_handle_main_menu_cancel(active_panel, base_scene_id)

		U_NavigationReducer.SHELL_ENDGAME:
			_handle_endgame_cancel(base_scene_id)


## Handle cancel in gameplay shell (B button - close overlays only)
func _handle_gameplay_cancel(overlay_stack: Array) -> void:
	if not overlay_stack.is_empty():
		# Has overlays → close top overlay
		# CloseMode (RESUME_TO_GAMEPLAY vs RETURN_TO_PREVIOUS_OVERLAY) is handled by reducer
		_store.dispatch(U_NavigationActions.close_top_overlay())
	# If no overlays, do nothing (ui_pause handles opening pause menu)


## Handle cancel in main menu shell
func _handle_main_menu_cancel(active_panel: StringName, base_scene_id: StringName) -> void:
	# Only apply root-panel behavior when the active base scene is the main
	# menu itself. Standalone menu scenes (settings_menu, gamepad_settings,
	# touchscreen_settings, input_rebinding, etc.) run in the main_menu shell
	# but manage their own back behavior via BasePanel/_on_back_pressed, so
	# M_UIInputHandler must not swallow ui_cancel in those cases.
	if base_scene_id != U_NavigationReducer.SHELL_MAIN_MENU:
		return

	if active_panel != U_NavigationReducer.DEFAULT_MENU_PANEL:
		# Not at root panel → return to main panel
		_store.dispatch(U_NavigationActions.set_menu_panel(U_NavigationReducer.DEFAULT_MENU_PANEL))
	# else: at root panel → no-op (back does nothing)


## Handle cancel in endgame shell
func _handle_endgame_cancel(base_scene_id: StringName) -> void:
	match base_scene_id:
		StringName("game_over"):
			# Game over → retry from checkpoint
			_store.dispatch(U_NavigationActions.retry())

		StringName("victory"):
			# Victory → skip to credits
			_store.dispatch(U_NavigationActions.skip_to_credits())

		StringName("credits"):
			# Credits → return to main menu
			_store.dispatch(U_NavigationActions.skip_to_menu())
