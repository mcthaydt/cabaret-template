extends RefCounted
class_name U_UIRegistry

## Static registry for UI screens and overlays.
##
## Loads RS_UIScreenDefinition resources from disk and provides lookup helpers
## used by navigation reducers/selectors.

# Preload all UI screen definitions (required for exported builds)
const MAIN_MENU_SCREEN := preload("res://resources/ui_screens/main_menu_screen.tres")
const GAME_OVER_SCREEN := preload("res://resources/ui_screens/game_over_screen.tres")
const VICTORY_SCREEN := preload("res://resources/ui_screens/victory_screen.tres")
const CREDITS_SCREEN := preload("res://resources/ui_screens/credits_screen.tres")
const PAUSE_MENU_OVERLAY := preload("res://resources/ui_screens/pause_menu_overlay.tres")
const SETTINGS_MENU_OVERLAY := preload("res://resources/ui_screens/settings_menu_overlay.tres")
const INPUT_PROFILE_SELECTOR_OVERLAY := preload("res://resources/ui_screens/input_profile_selector_overlay.tres")
const GAMEPAD_SETTINGS_OVERLAY := preload("res://resources/ui_screens/gamepad_settings_overlay.tres")
const TOUCHSCREEN_SETTINGS_OVERLAY := preload("res://resources/ui_screens/touchscreen_settings_overlay.tres")
const INPUT_REBINDING_OVERLAY := preload("res://resources/ui_screens/input_rebinding_overlay.tres")
const EDIT_TOUCH_CONTROLS_OVERLAY := preload("res://resources/ui_screens/edit_touch_controls_overlay.tres")

static var _screens: Dictionary = {}

static func _static_init() -> void:
	_register_all_screens()

static func _register_all_screens() -> void:
	# Explicitly register all preloaded screen definitions
	_register_definition(MAIN_MENU_SCREEN as RS_UIScreenDefinition)
	_register_definition(GAME_OVER_SCREEN as RS_UIScreenDefinition)
	_register_definition(VICTORY_SCREEN as RS_UIScreenDefinition)
	_register_definition(CREDITS_SCREEN as RS_UIScreenDefinition)
	_register_definition(PAUSE_MENU_OVERLAY as RS_UIScreenDefinition)
	_register_definition(SETTINGS_MENU_OVERLAY as RS_UIScreenDefinition)
	_register_definition(INPUT_PROFILE_SELECTOR_OVERLAY as RS_UIScreenDefinition)
	_register_definition(GAMEPAD_SETTINGS_OVERLAY as RS_UIScreenDefinition)
	_register_definition(TOUCHSCREEN_SETTINGS_OVERLAY as RS_UIScreenDefinition)
	_register_definition(INPUT_REBINDING_OVERLAY as RS_UIScreenDefinition)
	_register_definition(EDIT_TOUCH_CONTROLS_OVERLAY as RS_UIScreenDefinition)

## Reload registry entries from disk or a provided list (useful for tests).
static func reload_registry(definitions: Array = []) -> void:
	_screens.clear()

	if not definitions.is_empty():
		# Test mode: use provided definitions
		for definition in definitions:
			_register_definition(definition)
		return

	# Normal mode: use preloaded definitions
	_register_all_screens()

## Get screen definition by id (defensive copy).
static func get_screen(screen_id: StringName) -> Dictionary:
	if _screens.has(screen_id):
		return (_screens[screen_id] as RS_UIScreenDefinition).to_dictionary()
	return {}

## Get overlay definitions allowed in the given shell.
static func get_overlays_for_shell(shell: StringName) -> Array:
	var overlays: Array = []
	for definition in _screens.values():
		var screen_def := definition as RS_UIScreenDefinition
		if screen_def.kind == RS_UIScreenDefinition.UIScreenKind.OVERLAY and screen_def.allowed_shells.has(shell):
			overlays.append(screen_def.to_dictionary())
	return overlays

## Get close mode for a screen (defaults to RESUME_TO_GAMEPLAY if unknown).
static func get_close_mode(screen_id: StringName) -> int:
	if _screens.has(screen_id):
		return (_screens[screen_id] as RS_UIScreenDefinition).close_mode
	return RS_UIScreenDefinition.CloseMode.RESUME_TO_GAMEPLAY

## Validate overlay can be opened from the given parent overlay id.
static func is_valid_overlay_for_parent(overlay_id: StringName, parent_id: StringName) -> bool:
	if not _screens.has(overlay_id):
		return false

	var definition := _screens[overlay_id] as RS_UIScreenDefinition

	if definition.kind != RS_UIScreenDefinition.UIScreenKind.OVERLAY:
		return false

	if parent_id == StringName(""):
		return definition.allowed_parents.is_empty()

	return definition.allowed_parents.has(parent_id)

## Validate all loaded definitions.
static func validate_all() -> bool:
	var is_valid: bool = true
	for definition in _screens.values():
		if not (definition as RS_UIScreenDefinition).validate():
			is_valid = false
	return is_valid

static func _load_definitions_from_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path: String = dir_path + file_name
			var resource: Resource = load(resource_path)

			if not (resource is RS_UIScreenDefinition):
				push_warning("U_UIRegistry: Resource at %s is not RS_UIScreenDefinition, skipping" % resource_path)
				file_name = dir.get_next()
				continue

			_register_definition(resource as RS_UIScreenDefinition)

		file_name = dir.get_next()
	dir.list_dir_end()

static func _register_definition(definition: RS_UIScreenDefinition) -> void:
	if definition == null:
		return

	var screen_id: StringName = definition.screen_id
	if screen_id == StringName(""):
		push_error("U_UIRegistry: screen_id is empty on definition, skipping")
		return

	if _screens.has(screen_id):
		push_warning("U_UIRegistry: Duplicate screen_id %s encountered, skipping" % screen_id)
		return

	_screens[screen_id] = definition
