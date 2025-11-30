@icon("res://resources/editor_icons/utility.svg")
extends "res://scripts/ui/base/base_overlay.gd"

## Pause Menu - overlay wired into navigation actions
##
## Buttons dispatch navigation actions instead of calling Scene Manager directly.

const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")

# VERSION MARKER: v2 - Fixed GDScript syntax (2025-11-29)
const SCRIPT_VERSION := "v2-syntax-fix-2025-11-29"

const OVERLAY_SETTINGS := StringName("settings_menu_overlay")
const OVERLAY_INPUT_PROFILE := StringName("input_profile_selector")
const OVERLAY_GAMEPAD_SETTINGS := StringName("gamepad_settings")
const OVERLAY_TOUCHSCREEN_SETTINGS := StringName("touchscreen_settings")
const OVERLAY_INPUT_REBINDING := StringName("input_rebinding")

@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _input_profiles_button: Button = %InputProfilesButton
@onready var _gamepad_settings_button: Button = %GamepadSettingsButton
@onready var _touchscreen_settings_button: Button = %TouchscreenSettingsButton
@onready var _rebind_controls_button: Button = %RebindControlsButton
@onready var _quit_button: Button = %QuitButton

func _ready() -> void:
	print("========================================")
	print("[PAUSE_MENU] SCRIPT VERSION: ", SCRIPT_VERSION)
	print("[PAUSE_MENU] _ready() called - starting initialization")
	print("========================================")
	await super._ready()
	print("[PAUSE_MENU] _ready() completed after super._ready()")

func _on_store_ready(store_ref: M_StateStore) -> void:
	print("[PAUSE_MENU] _on_store_ready() called with store=", store_ref)
	# Subscribe to navigation state to hide when shell changes away from gameplay
	if store_ref != null:
		store_ref.slice_updated.connect(_on_navigation_changed)
	print("[PAUSE_MENU] _on_store_ready() complete")

func _exit_tree() -> void:
	var store := get_store()
	if store != null and store.slice_updated.is_connected(_on_navigation_changed):
		store.slice_updated.disconnect(_on_navigation_changed)

func _on_navigation_changed(slice_name: StringName, _slice_state: Dictionary) -> void:
	if slice_name != StringName("navigation"):
		return

	var store := get_store()
	if store == null:
		return

	var nav_state: Dictionary = store.get_slice(StringName("navigation"))
	var shell: StringName = nav_state.get("shell", StringName())

	# Hide pause menu when transitioning away from gameplay
	if shell != StringName("gameplay"):
		visible = false

func _on_panel_ready() -> void:
	print("========================================")
	print("[PAUSE_MENU] _on_panel_ready() CALLED!")
	print("[PAUSE_MENU] SCRIPT VERSION IN PANEL_READY: ", SCRIPT_VERSION)
	print("========================================")
	_connect_buttons()
	print("[PAUSE_MENU] Buttons connected")
	_log_button_setup()
	_setup_input_logging()
	print("[PAUSE_MENU] _on_panel_ready() COMPLETE!")

func _connect_buttons() -> void:
	print("[PAUSE_MENU] _connect_buttons() starting...")
	print("[PAUSE_MENU]   _resume_button = ", _resume_button)
	print("[PAUSE_MENU]   _settings_button = ", _settings_button)
	print("[PAUSE_MENU]   _input_profiles_button = ", _input_profiles_button)
	print("[PAUSE_MENU]   _gamepad_settings_button = ", _gamepad_settings_button)
	print("[PAUSE_MENU]   _touchscreen_settings_button = ", _touchscreen_settings_button)
	print("[PAUSE_MENU]   _rebind_controls_button = ", _rebind_controls_button)
	print("[PAUSE_MENU]   _quit_button = ", _quit_button)

	if _resume_button != null and not _resume_button.pressed.is_connected(_on_resume_pressed):
		_resume_button.pressed.connect(_on_resume_pressed)
		print("[PAUSE_MENU]   ✓ Connected Resume button")
	if _settings_button != null and not _settings_button.pressed.is_connected(_on_settings_pressed):
		_settings_button.pressed.connect(_on_settings_pressed)
		print("[PAUSE_MENU]   ✓ Connected Settings button")
	if _input_profiles_button != null and not _input_profiles_button.pressed.is_connected(_on_input_profiles_pressed):
		_input_profiles_button.pressed.connect(_on_input_profiles_pressed)
		print("[PAUSE_MENU]   ✓ Connected Input Profiles button")
	if _gamepad_settings_button != null and not _gamepad_settings_button.pressed.is_connected(_on_gamepad_settings_pressed):
		_gamepad_settings_button.pressed.connect(_on_gamepad_settings_pressed)
		print("[PAUSE_MENU]   ✓ Connected Gamepad Settings button")
	if _touchscreen_settings_button != null and not _touchscreen_settings_button.pressed.is_connected(_on_touchscreen_settings_pressed):
		_touchscreen_settings_button.pressed.connect(_on_touchscreen_settings_pressed)
		print("[PAUSE_MENU]   ✓ Connected Touchscreen Settings button")
	if _rebind_controls_button != null and not _rebind_controls_button.pressed.is_connected(_on_rebind_controls_pressed):
		_rebind_controls_button.pressed.connect(_on_rebind_controls_pressed)
		print("[PAUSE_MENU]   ✓ Connected Rebind Controls button")
	if _quit_button != null and not _quit_button.pressed.is_connected(_on_quit_pressed):
		_quit_button.pressed.connect(_on_quit_pressed)
		print("[PAUSE_MENU]   ✓ Connected Quit button")

func _on_resume_pressed() -> void:
	print("[PAUSE_MENU] ►►► Resume button PRESSED signal fired!")
	_dispatch_navigation(U_NavigationActions.close_pause())

func _on_settings_pressed() -> void:
	print("[PAUSE_MENU] ►►► Settings button PRESSED signal fired!")
	_log_mobile_controls_state()

	# DIAGNOSTIC: Check navigation state
	var store := get_store()
	if store != null:
		var nav_state := store.get_slice(StringName("navigation"))
		print("[DIAG-NAV] shell = ", nav_state.get("shell", "<MISSING>"))
		print("[DIAG-NAV] overlay_stack = ", nav_state.get("overlay_stack", []))
		print("[DIAG-NAV] base_scene_id = ", nav_state.get("base_scene_id", "<MISSING>"))
	else:
		print("[DIAG-NAV] ERROR: Store is null!")

	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_SETTINGS))

func _on_input_profiles_pressed() -> void:
	print("[PAUSE_MENU] ►►► Input Profiles button PRESSED signal fired!")
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_INPUT_PROFILE))

func _on_gamepad_settings_pressed() -> void:
	print("[PAUSE_MENU] ►►► Gamepad Settings button PRESSED signal fired!")

	# DIAGNOSTIC: Check navigation state
	var store := get_store()
	if store != null:
		var nav_state := store.get_slice(StringName("navigation"))
		print("[DIAG-NAV] shell = ", nav_state.get("shell", "<MISSING>"))
		print("[DIAG-NAV] overlay_stack = ", nav_state.get("overlay_stack", []))
	else:
		print("[DIAG-NAV] ERROR: Store is null!")

	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_GAMEPAD_SETTINGS))

func _on_touchscreen_settings_pressed() -> void:
	print("[PAUSE_MENU] ►►► Touchscreen Settings button PRESSED signal fired!")
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_TOUCHSCREEN_SETTINGS))

func _on_rebind_controls_pressed() -> void:
	print("[PAUSE_MENU] ►►► Rebind Controls button PRESSED signal fired!")
	_dispatch_navigation(U_NavigationActions.open_overlay(OVERLAY_INPUT_REBINDING))

func _on_quit_pressed() -> void:
	print("[PAUSE_MENU] ►►► Quit button PRESSED signal fired!")
	_dispatch_navigation(U_NavigationActions.return_to_main_menu())

func _on_back_pressed() -> void:
	print("[PAUSE_MENU] ►►► Back action triggered!")
	_on_resume_pressed()

func _dispatch_navigation(action: Dictionary) -> void:
	if action.is_empty():
		return
	var store := get_store()
	if store == null:
		return
	store.dispatch(action)

func _log_button_setup() -> void:
	print("[PAUSE_MENU] ===== Button Setup Diagnostics =====")
	_log_button_info("Resume", _resume_button)
	_log_button_info("Settings", _settings_button)
	_log_button_info("Input Profiles", _input_profiles_button)
	_log_button_info("Gamepad Settings", _gamepad_settings_button)
	_log_button_info("Touchscreen Settings", _touchscreen_settings_button)
	_log_button_info("Rebind Controls", _rebind_controls_button)
	_log_button_info("Quit", _quit_button)

	# Check parent container mouse filters
	var vbox := get_node_or_null("%VBoxContainer")
	if vbox and vbox is Control:
		print("[PAUSE_MENU] VBoxContainer mouse_filter=", vbox.mouse_filter)

	# Check root control
	print("[PAUSE_MENU] PauseMenu root mouse_filter=", mouse_filter)

	# Check canvas layer info
	var pause_canvas := _get_parent_canvas_layer(self)
	if pause_canvas:
		print("[PAUSE_MENU] Pause menu CanvasLayer: ", pause_canvas.name, " layer=", pause_canvas.layer)
	else:
		print("[PAUSE_MENU] No CanvasLayer parent found")

	# Check mobile controls
	_log_mobile_controls_state()

func _log_mobile_controls_state() -> void:
	var mobile_controls := get_tree().get_first_node_in_group("mobile_controls")
	if mobile_controls:
		print("[PAUSE_MENU] MobileControls found: visible=", mobile_controls.visible)
		if mobile_controls is CanvasLayer:
			print("[PAUSE_MENU] MobileControls layer=", mobile_controls.layer)

		# Get virtual buttons and their positions
		if mobile_controls.has_method("get_buttons"):
			var buttons: Array = mobile_controls.get_buttons()
			print("[PAUSE_MENU] Virtual buttons count: ", buttons.size())
			for button in buttons:
				if button and is_instance_valid(button):
					print("[PAUSE_MENU]   Button action=", button.action, " pos=", button.global_position, " visible=", button.visible)
	else:
		print("[PAUSE_MENU] No MobileControls found")

	# Check button global positions
	if _settings_button:
		print("[PAUSE_MENU] Settings button global_pos=", _settings_button.global_position, " size=", _settings_button.size)
	if _resume_button:
		print("[PAUSE_MENU] Resume button global_pos=", _resume_button.global_position, " size=", _resume_button.size)
	if _quit_button:
		print("[PAUSE_MENU] Quit button global_pos=", _quit_button.global_position, " size=", _quit_button.size)

func _log_button_info(label: String, button: Button) -> void:
	if button:
		print("[PAUSE_MENU] ", label, " button: disabled=", button.disabled, " visible=", button.visible, " mouse_filter=", button.mouse_filter)
	else:
		print("[PAUSE_MENU] ", label, " button: NULL")

func _setup_input_logging() -> void:
	# Add input logging to each button
	if _settings_button:
		_settings_button.gui_input.connect(func(event: InputEvent) -> void:
			print("[PAUSE_MENU] Settings button received input event: ", event)
		)
	if _input_profiles_button:
		_input_profiles_button.gui_input.connect(func(event: InputEvent) -> void:
			print("[PAUSE_MENU] Input Profiles button received input event: ", event)
		)
	if _gamepad_settings_button:
		_gamepad_settings_button.gui_input.connect(func(event: InputEvent) -> void:
			print("[PAUSE_MENU] Gamepad Settings button received input event: ", event)
		)
	if _touchscreen_settings_button:
		_touchscreen_settings_button.gui_input.connect(func(event: InputEvent) -> void:
			print("[PAUSE_MENU] Touchscreen Settings button received input event: ", event)
		)
	if _rebind_controls_button:
		_rebind_controls_button.gui_input.connect(func(event: InputEvent) -> void:
			print("[PAUSE_MENU] Rebind Controls button received input event: ", event)
		)
	if _resume_button:
		_resume_button.gui_input.connect(func(event: InputEvent) -> void:
			print("[PAUSE_MENU] Resume button received input event: ", event)
		)
	if _quit_button:
		_quit_button.gui_input.connect(func(event: InputEvent) -> void:
			print("[PAUSE_MENU] Quit button received input event: ", event)
		)

func _get_parent_canvas_layer(node: Node) -> CanvasLayer:
	var current := node.get_parent()
	while current != null:
		if current is CanvasLayer:
			return current as CanvasLayer
		current = current.get_parent()
	return null
