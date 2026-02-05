extends GutTest

## Tests for hiding desktop-only display settings on mobile platforms

const UI_DisplaySettingsTab := preload("res://scripts/ui/settings/ui_display_settings_tab.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

var _store: M_StateStore
var _tab: Control
var _original_mobile_feature: bool

func before_all() -> void:
	# Store original mobile feature state
	_original_mobile_feature = OS.has_feature("mobile")

func after_all() -> void:
	# Restore original mobile feature state if we modified it
	pass

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

func test_desktop_controls_visible_on_desktop() -> void:
	# GIVEN: Running on desktop platform (not mobile)
	if OS.has_feature("mobile"):
		pending("Test requires desktop platform")
		return

	# WHEN: Display settings tab is instantiated
	var scene := load("res://scenes/ui/overlays/settings/ui_display_settings_tab.tscn")
	_tab = scene.instantiate()
	add_child_autofree(_tab)
	await get_tree().process_frame

	# THEN: Desktop-only controls should be visible
	var window_size_row := _find_parent_row(_tab, "WindowSizeOption")
	var window_mode_row := _find_parent_row(_tab, "WindowModeOption")
	var vsync_row := _find_parent_row(_tab, "VSyncToggle")

	if window_size_row != null:
		assert_true(window_size_row.visible, "Window size control should be visible on desktop")
	if window_mode_row != null:
		assert_true(window_mode_row.visible, "Window mode control should be visible on desktop")
	if vsync_row != null:
		assert_true(vsync_row.visible, "VSync control should be visible on desktop")

func test_desktop_controls_hidden_on_mobile() -> void:
	# GIVEN: Running on mobile platform
	# Note: This test will be skipped on desktop since we can't easily mock OS.has_feature()
	# Use --emulate-mobile flag to test mobile behavior
	if not OS.has_feature("mobile"):
		pending("Test requires mobile platform (use --emulate-mobile)")
		return

	# WHEN: Display settings tab is instantiated
	var scene := load("res://scenes/ui/overlays/settings/ui_display_settings_tab.tscn")
	_tab = scene.instantiate()
	add_child_autofree(_tab)
	await get_tree().process_frame

	# THEN: Desktop-only controls should be hidden
	var window_size_row := _find_parent_row(_tab, "WindowSizeOption")
	var window_mode_row := _find_parent_row(_tab, "WindowModeOption")
	var vsync_row := _find_parent_row(_tab, "VSyncToggle")

	if window_size_row != null:
		assert_false(window_size_row.visible, "Window size control should be hidden on mobile")
	if window_mode_row != null:
		assert_false(window_mode_row.visible, "Window mode control should be hidden on mobile")
	if vsync_row != null:
		assert_false(vsync_row.visible, "VSync control should be hidden on mobile")

func test_mobile_controls_still_visible_on_mobile() -> void:
	# GIVEN: Running on mobile platform
	if not OS.has_feature("mobile"):
		pending("Test requires mobile platform (use --emulate-mobile)")
		return

	# WHEN: Display settings tab is instantiated
	var scene := load("res://scenes/ui/overlays/settings/ui_display_settings_tab.tscn")
	_tab = scene.instantiate()
	add_child_autofree(_tab)
	await get_tree().process_frame

	# THEN: Mobile-compatible controls should still be visible
	var quality_row := _find_parent_row(_tab, "QualityPresetOption")
	var ui_scale_row := _find_parent_row(_tab, "UIScaleSlider")

	if quality_row != null:
		assert_true(quality_row.visible, "Quality preset should be visible on mobile")
	if ui_scale_row != null:
		assert_true(ui_scale_row.visible, "UI scale should be visible on mobile")

func _find_parent_row(root: Node, child_name: String) -> Control:
	# Find the control and return its parent row container
	var control := root.find_child(child_name, true, false)
	if control == null:
		return null
	var parent := control.get_parent()
	if parent is Control:
		return parent as Control
	return null
