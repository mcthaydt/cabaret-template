extends GutTest

## Tests for display settings tab post-processing preset dropdown

const UI_DisplaySettingsTab := preload("res://scripts/ui/settings/ui_display_settings_tab.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const U_DisplayActions := preload("res://scripts/state/actions/u_display_actions.gd")

var _store: M_StateStore
var _tab: Control

func before_each() -> void:
	_store = M_StateStore.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await get_tree().process_frame

func after_each() -> void:
	U_ServiceLocator.clear()
	if _tab != null and is_instance_valid(_tab):
		_tab.queue_free()
		_tab = null

func test_post_processing_preset_dropdown_exists() -> void:
	# GIVEN: Display settings tab is loaded
	var scene := load("res://scenes/ui/overlays/settings/ui_display_settings_tab.tscn")
	_tab = scene.instantiate()
	add_child_autofree(_tab)
	await get_tree().process_frame

	# THEN: Should have a post-processing preset dropdown
	var preset_option := _tab.find_child("PostProcessPresetOption", true, false)
	assert_not_null(preset_option, "Should have PostProcessPresetOption dropdown")
	assert_true(preset_option is OptionButton, "PostProcessPresetOption should be an OptionButton")

func test_post_processing_preset_dropdown_has_three_options() -> void:
	# GIVEN: Display settings tab is loaded
	var scene := load("res://scenes/ui/overlays/settings/ui_display_settings_tab.tscn")
	_tab = scene.instantiate()
	add_child_autofree(_tab)
	await get_tree().process_frame

	# THEN: Dropdown should have light, medium, and heavy options
	var preset_option: OptionButton = _tab.find_child("PostProcessPresetOption", true, false)
	assert_eq(preset_option.item_count, 3, "Should have 3 preset options")

	# Check that the options are in the correct order (light, medium, heavy)
	var first_text := preset_option.get_item_text(0)
	var second_text := preset_option.get_item_text(1)
	var third_text := preset_option.get_item_text(2)

	assert_true(first_text.to_lower() == "light", "First option should be Light")
	assert_true(second_text.to_lower() == "medium", "Second option should be Medium")
	assert_true(third_text.to_lower() == "heavy", "Third option should be Heavy")

func test_selecting_preset_dispatches_action() -> void:
	# GIVEN: Display settings tab with preset dropdown
	var scene := load("res://scenes/ui/overlays/settings/ui_display_settings_tab.tscn")
	_tab = scene.instantiate()
	add_child_autofree(_tab)
	await get_tree().process_frame

	var preset_option: OptionButton = _tab.find_child("PostProcessPresetOption", true, false)

	# Track dispatched actions
	var dispatched_actions: Array = []
	var original_dispatch := _store.dispatch
	_store.dispatch = func(action: Dictionary) -> void:
		dispatched_actions.append(action)
		original_dispatch.call(action)

	# WHEN: Selecting the "heavy" preset (index 2)
	preset_option.select(2)
	preset_option.item_selected.emit(2)
	await get_tree().process_frame

	# THEN: Should dispatch set_post_processing_preset action with "heavy"
	var found_action := false
	for action in dispatched_actions:
		if action.get("type") == U_DisplayActions.ACTION_SET_POST_PROCESSING_PRESET:
			var payload: Dictionary = action.get("payload", {})
			assert_eq(payload.get("preset"), "heavy", "Should dispatch action with heavy preset")
			found_action = true
			break

	assert_true(found_action, "Should have dispatched set_post_processing_preset action")

func test_medium_preset_is_default_selection() -> void:
	# GIVEN: Display settings tab is loaded with default state
	var scene := load("res://scenes/ui/overlays/settings/ui_display_settings_tab.tscn")
	_tab = scene.instantiate()
	add_child_autofree(_tab)
	await get_tree().process_frame

	# THEN: Medium preset should be selected by default
	var preset_option: OptionButton = _tab.find_child("PostProcessPresetOption", true, false)
	var selected_index := preset_option.selected
	var selected_text := preset_option.get_item_text(selected_index)

	assert_eq(selected_text.to_lower(), "medium", "Medium preset should be selected by default")
