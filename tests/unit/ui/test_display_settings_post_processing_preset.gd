extends GutTest

## Tests for display settings tab post-processing preset dropdown


var _store: M_StateStore
var _tab: Control

func before_each() -> void:
	U_StateHandoff.clear_all()
	U_ServiceLocator.clear()
	_store = M_StateStore.new()
	var test_settings := RS_StateStoreSettings.new()
	test_settings.enable_persistence = false
	test_settings.enable_global_settings_persistence = false
	test_settings.enable_debug_logging = false
	test_settings.enable_debug_overlay = false
	_store.settings = test_settings
	_store.display_initial_state = RS_DisplayInitialState.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await get_tree().process_frame

func after_each() -> void:
	U_StateHandoff.clear_all()
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

func test_selecting_preset_updates_state() -> void:
	# GIVEN: Display settings tab with preset dropdown
	var scene := load("res://scenes/ui/overlays/settings/ui_display_settings_tab.tscn")
	_tab = scene.instantiate()
	add_child_autofree(_tab)
	await get_tree().process_frame

	var preset_option: OptionButton = _tab.find_child("PostProcessPresetOption", true, false)

	# WHEN: User changes selection to "heavy" preset (index 2)
	preset_option.select(2)
	preset_option.item_selected.emit(2)
	await get_tree().process_frame

	# Click apply button to commit changes
	var apply_button: Button = _tab.find_child("ApplyButton", true, false)
	if apply_button != null:
		apply_button.pressed.emit()
		await get_tree().process_frame

	# THEN: State should be updated with heavy preset
	var state := _store.get_state()
	var display_state: Dictionary = state.get("display", {})
	assert_eq(display_state.get("post_processing_preset"), "heavy", "State should have heavy preset after selection")

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
