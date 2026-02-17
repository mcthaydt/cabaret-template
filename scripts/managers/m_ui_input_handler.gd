@icon("res://assets/editor_icons/icn_manager.svg")
extends Node
class_name M_UIInputHandler

## Thin UI input handler for context-based navigation routing
##
## Listens to ui_* actions and dispatches navigation actions based on current
## shell, overlay stack, and panel state. Does NOT hardcode physical keys or
## maintain separate navigation state.


var _store: I_StateStore = null


func _ready() -> void:
	# Run in PROCESS_MODE_ALWAYS to handle pause/unpause
	process_mode = PROCESS_MODE_ALWAYS

	# Wait for store to be ready
	await get_tree().process_frame
	_store = U_StateUtils.get_store(self)

	if _store == null:
		push_error("M_UIInputHandler: Failed to find M_StateStore")


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
	var is_root_menu_scene: bool = (
		base_scene_id == U_NavigationReducer.SHELL_MAIN_MENU
		or base_scene_id == StringName("language_selector")
	)
	if not is_root_menu_scene:
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
