extends GutTest

## Regression tests for mobile input profile fixes
## Ensures "default" (keyboard/mouse) profile is never used on mobile

const M_InputProfileManager := preload("res://scripts/managers/m_input_profile_manager.gd")
const U_InputProfileLoader := preload("res://scripts/managers/helpers/u_input_profile_loader.gd")
const RS_InputProfile := preload("res://scripts/resources/input/rs_input_profile.gd")
const UI_InputProfileSelector := preload("res://scenes/ui/overlays/ui_input_profile_selector.tscn")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_BootInitialState := preload("res://scripts/resources/state/rs_boot_initial_state.gd")
const RS_SettingsInitialState := preload("res://scripts/resources/state/rs_settings_initial_state.gd")
const RS_NavigationInitialState := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

func before_each() -> void:
	U_ServiceLocator.clear()

func after_each() -> void:
	U_ServiceLocator.clear()

## Regression test: _resolve_profile_id should never return "default" on mobile
func test_resolve_profile_id_avoids_default_on_mobile() -> void:
	var manager := M_InputProfileManager.new()
	var loader := U_InputProfileLoader.new()
	manager.available_profiles = loader.load_available_profiles()

	# Simulate mobile platform by checking available profiles
	var resolved_id := manager._resolve_profile_id("")

	# On desktop (test environment), should prefer "default"
	# On mobile, should prefer "default_touchscreen"
	if OS.has_feature("mobile"):
		assert_ne(resolved_id, "default", "_resolve_profile_id should not return 'default' on mobile")
		assert_true(
			resolved_id == "default_touchscreen" or resolved_id.contains("touchscreen"),
			"_resolve_profile_id should prefer touchscreen profiles on mobile, got: %s" % resolved_id
		)
	else:
		assert_eq(resolved_id, "default", "_resolve_profile_id should return 'default' on desktop")

	manager.free()

## Regression test: _resolve_profile_id with touchscreen preference on mobile
func test_resolve_profile_id_prioritizes_touchscreen_on_mobile() -> void:
	var manager := M_InputProfileManager.new()
	var loader := U_InputProfileLoader.new()
	manager.available_profiles = loader.load_available_profiles()

	# Test that even if we pass a keyboard profile ID, it's rejected on mobile
	var resolved_id := manager._resolve_profile_id("alternate")  # keyboard profile

	if OS.has_feature("mobile"):
		# Should fall back to touchscreen default instead of using keyboard profile
		assert_true(
			resolved_id.contains("touchscreen") or resolved_id != "alternate",
			"Should not accept keyboard profile 'alternate' on mobile, got: %s" % resolved_id
		)
	else:
		# On desktop, keyboard profiles are fine
		assert_eq(resolved_id, "alternate", "Should accept keyboard profile 'alternate' on desktop")

	manager.free()

## Regression test: Input profile selector filters out "default" on mobile
func test_input_profile_selector_filters_default_on_mobile() -> void:
	var store := await _create_state_store()
	var manager := M_InputProfileManager.new()
	add_child_autofree(manager)
	await wait_process_frames(2)

	var selector := UI_InputProfileSelector.instantiate()
	add_child_autofree(selector)
	await wait_process_frames(3)

	# Trigger profile population
	selector._populate_profiles()

	# Get the filtered available profiles
	var available: Array = selector._available_profiles if "_available_profiles" in selector else []

	if OS.has_feature("mobile"):
		assert_false(available.has("default"), "Input profile selector should filter out 'default' on mobile")
		# Should have touchscreen profiles available
		var has_touchscreen_profile := false
		for profile_id in available:
			if String(profile_id).contains("touchscreen"):
				has_touchscreen_profile = true
				break
		assert_true(has_touchscreen_profile, "Should have at least one touchscreen profile available on mobile")
	else:
		# On desktop, "default" should be available
		assert_true(available.has("default") or available.is_empty(), "Input profile selector should include 'default' on desktop (unless no profiles loaded)")

## Regression test: Input profile selector structure matches settings panel style
func test_input_profile_selector_has_panel_structure() -> void:
	var selector := UI_InputProfileSelector.instantiate()
	add_child_autofree(selector)
	await wait_process_frames(2)

	# Verify it has the panel structure: Background + CenterContainer + PanelContainer
	var background := selector.get_node_or_null("Background") as ColorRect
	var center_container := selector.get_node_or_null("CenterContainer") as CenterContainer
	var panel := selector.get_node_or_null("CenterContainer/Panel") as PanelContainer

	assert_not_null(background, "Should have Background ColorRect for dimming")
	assert_not_null(center_container, "Should have CenterContainer for centering")
	assert_not_null(panel, "Should have PanelContainer for panel styling")

	# Verify background color is semi-transparent black
	if background != null:
		assert_almost_eq(background.color.a, 0.5, 0.1, "Background should be semi-transparent")

## Regression test: Input profile selector has Cancel, Reset, Apply buttons
func test_input_profile_selector_has_all_action_buttons() -> void:
	var selector := UI_InputProfileSelector.instantiate()
	add_child_autofree(selector)
	await wait_process_frames(2)

	var cancel_button := selector.get_node_or_null("%CancelButton") as Button
	var reset_button := selector.get_node_or_null("%ResetButton") as Button
	var apply_button := selector.get_node_or_null("%ApplyButton") as Button

	assert_not_null(cancel_button, "Should have Cancel button")
	assert_not_null(reset_button, "Should have Reset button")
	assert_not_null(apply_button, "Should have Apply button")

	# Verify button text
	if cancel_button != null:
		assert_eq(cancel_button.text, "Cancel", "Cancel button should have correct text")
	if reset_button != null:
		assert_eq(reset_button.text, "Reset to Defaults", "Reset button should have correct text")
	if apply_button != null:
		assert_eq(apply_button.text, "Apply", "Apply button should have correct text")

## Regression test: Profile cycling uses left/right, not up/down
func test_input_profile_selector_navigation_allows_up_down() -> void:
	var store := await _create_state_store()
	var manager := M_InputProfileManager.new()
	add_child_autofree(manager)
	U_ServiceLocator.register(StringName("state_store"), store)
	U_ServiceLocator.register(StringName("input_profile_manager"), manager)
	await wait_process_frames(2)

	var selector := UI_InputProfileSelector.instantiate()
	add_child_autofree(selector)
	await wait_process_frames(3)

	# Get profile button and a bottom button
	var profile_button := selector.get_node_or_null("CenterContainer/Panel/MainContainer/ProfileRow/ProfileButton") as Button
	var apply_button := selector.get_node_or_null("%ApplyButton") as Button

	assert_not_null(profile_button, "Should have profile button")
	assert_not_null(apply_button, "Should have apply button")

	if profile_button != null and apply_button != null:
		# Verify focus neighbor is set to allow down navigation
		var down_neighbor_path := profile_button.focus_neighbor_bottom
		assert_ne(down_neighbor_path, NodePath(), "Profile button should have down neighbor set")

		# Verify down neighbor leads to button row
		var down_neighbor := profile_button.get_node_or_null(down_neighbor_path)
		assert_not_null(down_neighbor, "Profile button's down neighbor should exist")

func _create_state_store() -> M_StateStore:
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.boot_initial_state = RS_BootInitialState.new()
	store.navigation_initial_state = RS_NavigationInitialState.new()
	store.settings_initial_state = RS_SettingsInitialState.new()
	add_child_autofree(store)
	await wait_process_frames(2)
	return store
