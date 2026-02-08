extends GutTest

## Tests for high contrast mode in display manager


var _manager: Node
var _store: Node

func before_each() -> void:
	U_ServiceLocator.clear()

func after_each() -> void:
	U_ServiceLocator.clear()
	_manager = null
	_store = null

func test_high_contrast_mode_loads_high_contrast_palette() -> void:
	# GIVEN: Display settings with high contrast enabled and normal color blind mode
	await _setup_manager_with_store({"high_contrast_enabled": true, "color_blind_mode": "normal"})

	# WHEN: Getting the active palette
	var palette: Resource = _manager.get_active_palette()

	# THEN: Normal high contrast palette should be loaded (combines mode + high contrast)
	assert_not_null(palette, "High contrast palette should be loaded")
	if palette != null and "palette_id" in palette:
		assert_eq(palette.palette_id, StringName("normal_high_contrast"), "Palette ID should be 'normal_high_contrast'")

func test_high_contrast_combines_with_color_blind_mode() -> void:
	# GIVEN: Display settings with deuteranopia mode AND high contrast enabled
	await _setup_manager_with_store({"color_blind_mode": "deuteranopia", "high_contrast_enabled": true})

	# WHEN: Getting the active palette
	var palette: Resource = _manager.get_active_palette()

	# THEN: Deuteranopia high contrast palette should be loaded (combines both features)
	assert_not_null(palette, "Deuteranopia high contrast palette should be loaded")
	if palette != null and "palette_id" in palette:
		assert_eq(palette.palette_id, StringName("deuteranopia_high_contrast"), "High contrast should combine with color blind mode")

func test_disabling_high_contrast_restores_color_blind_mode() -> void:
	# GIVEN: Display settings with deuteranopia mode initially
	await _setup_manager_with_store({"color_blind_mode": "deuteranopia", "high_contrast_enabled": true})

	# WHEN: Disabling high contrast
	_store.set_slice(StringName("display"), {"color_blind_mode": "deuteranopia", "high_contrast_enabled": false})
	_store.slice_updated.emit(StringName("display"), {"color_blind_mode": "deuteranopia", "high_contrast_enabled": false})

	# THEN: Deuteranopia palette should be restored
	var palette: Resource = _manager.get_active_palette()
	assert_not_null(palette, "Deuteranopia palette should be loaded")
	if palette != null and "palette_id" in palette:
		assert_eq(palette.palette_id, StringName("deuteranopia"), "Should restore deuteranopia mode")

func test_high_contrast_palette_has_correct_colors() -> void:
	# GIVEN: Display settings with high contrast enabled
	await _setup_manager_with_store({"high_contrast_enabled": true, "color_blind_mode": "normal"})

	# WHEN: Getting the active palette
	var palette: Resource = _manager.get_active_palette()

	# THEN: High contrast palette should have high contrast colors
	assert_not_null(palette, "High contrast palette should be loaded")
	if palette != null:
		# High contrast typically uses black/white or very high contrast colors
		if "text" in palette:
			# Text should be either very light or very dark
			var text_color: Color = palette.text
			var luminance := text_color.get_luminance()
			assert_true(luminance < 0.2 or luminance > 0.8, "Text should be high contrast (very dark or very light)")

func _setup_manager_with_store(display_state: Dictionary) -> void:
	_store = MockStateStore.new()
	_store.set_slice(StringName("display"), display_state)
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)

	var game_viewport := SubViewport.new()
	game_viewport.name = "GameViewport"
	add_child_autofree(game_viewport)

	_manager = M_DisplayManager.new()
	add_child_autofree(_manager)
	await get_tree().process_frame
