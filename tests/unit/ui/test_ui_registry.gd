extends GutTest

## Tests for UI registry definitions and lookup helpers.

const UIRegistry := preload("res://scripts/ui/u_ui_registry.gd")
const RS_UIScreenDefinition := preload("res://scripts/ui/resources/rs_ui_screen_definition.gd")

func before_each() -> void:
	UIRegistry.reload_registry()

func after_each() -> void:
	UIRegistry.reload_registry()

## T024: Registry loads base screens and overlays
func test_registry_loads_base_and_overlay_definitions() -> void:
	var main_menu: Dictionary = UIRegistry.get_screen(StringName("main_menu"))
	assert_ne(main_menu, {}, "Main menu definition should load")
	assert_eq(main_menu.get("screen_id"), StringName("main_menu"), "Main menu should keep its screen_id")
	assert_eq(main_menu.get("kind"), RS_UIScreenDefinition.UIScreenKind.BASE_SCENE, "Main menu should be a base scene")
	assert_eq(main_menu.get("close_mode"), RS_UIScreenDefinition.CloseMode.RESUME_TO_MENU, "Main menu should close to menu shell")

	var pause_menu: Dictionary = UIRegistry.get_screen(StringName("pause_menu"))
	assert_ne(pause_menu, {}, "Pause menu overlay should load")
	assert_eq(pause_menu.get("kind"), RS_UIScreenDefinition.UIScreenKind.OVERLAY, "Pause menu should be overlay kind")
	assert_eq(pause_menu.get("close_mode"), RS_UIScreenDefinition.CloseMode.RESUME_TO_GAMEPLAY, "Pause menu closes back to gameplay")

	assert_true(UIRegistry.validate_all(), "Default UI registry definitions should validate")

## T024: Overlay lookups by shell include all gameplay overlays
func test_get_overlays_for_shell_returns_all_gameplay_overlays() -> void:
	var overlays: Array = UIRegistry.get_overlays_for_shell(StringName("gameplay"))
	var overlay_ids: Array = []
	for overlay in overlays:
		overlay_ids.append(overlay.get("screen_id", StringName()))

	var expected_ids: Array = [
		StringName("pause_menu"),
		StringName("settings_menu_overlay"),
		StringName("input_profile_selector"),
		StringName("gamepad_settings"),
		StringName("vfx_settings"),
		StringName("touchscreen_settings"),
		StringName("input_rebinding"),
		StringName("edit_touch_controls"),
		StringName("save_load_menu_overlay")
	]

	for expected_id in expected_ids:
		assert_true(overlay_ids.has(expected_id), "Overlay list should contain %s" % expected_id)

	assert_eq(overlay_ids.size(), expected_ids.size(), "Overlay list should not contain unexpected overlays")

## T024: Close modes and parent validation guard navigation
func test_close_mode_and_parent_validation() -> void:
	assert_eq(
		UIRegistry.get_close_mode(StringName("settings_menu_overlay")),
		RS_UIScreenDefinition.CloseMode.RETURN_TO_PREVIOUS_OVERLAY,
		"Settings overlay should return to previous overlay"
	)

	assert_true(
		UIRegistry.is_valid_overlay_for_parent(StringName("settings_menu_overlay"), StringName("pause_menu")),
		"Settings overlay should allow pause_menu parent"
	)
	assert_true(
		UIRegistry.is_valid_overlay_for_parent(StringName("pause_menu"), StringName("")),
		"Pause overlay should be allowed without a parent"
	)
	assert_false(
		UIRegistry.is_valid_overlay_for_parent(StringName("settings_menu_overlay"), StringName("input_rebinding")),
		"Settings overlay should reject invalid parents"
	)

## T024: Validation fails when definition references missing scene or shell
func test_validation_fails_for_invalid_definitions() -> void:
	var invalid_definition := RS_UIScreenDefinition.new()
	invalid_definition.screen_id = StringName("invalid_overlay")
	invalid_definition.kind = RS_UIScreenDefinition.UIScreenKind.OVERLAY
	invalid_definition.scene_id = StringName("nonexistent_scene")
	invalid_definition.allowed_shells = [StringName("gameplay")]
	invalid_definition.allowed_parents = []
	invalid_definition.close_mode = RS_UIScreenDefinition.CloseMode.RESUME_TO_GAMEPLAY

	UIRegistry.reload_registry([invalid_definition])
	assert_false(UIRegistry.validate_all(), "Registry validation should fail when invalid definitions are present")
	assert_push_error("scene_id nonexistent_scene is not registered")
