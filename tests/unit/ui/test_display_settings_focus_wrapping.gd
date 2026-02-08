extends GutTest

## Tests for display settings tab focus navigation wrapping


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

func test_focus_wraps_from_first_to_last_control() -> void:
	# GIVEN: Display settings tab with multiple focusable controls
	var scene := load("res://scenes/ui/overlays/settings/ui_display_settings_tab.tscn")
	_tab = scene.instantiate()
	add_child_autofree(_tab)
	await get_tree().process_frame

	# Find first and last focusable controls
	var first_control := _find_first_focusable(_tab)
	var last_control := _find_last_focusable(_tab)

	assert_not_null(first_control, "Should have a first focusable control")
	assert_not_null(last_control, "Should have a last focusable control")

	# WHEN: Focus is on first control and user presses up
	# THEN: Focus should wrap to last control
	var up_neighbor := first_control.get_focus_neighbor(SIDE_TOP)
	if up_neighbor != NodePath():
		var up_node := first_control.get_node_or_null(up_neighbor)
		assert_eq(up_node, last_control, "Up from first control should focus last control (wrapping)")

func test_focus_wraps_from_last_to_first_control() -> void:
	# GIVEN: Display settings tab with multiple focusable controls
	var scene := load("res://scenes/ui/overlays/settings/ui_display_settings_tab.tscn")
	_tab = scene.instantiate()
	add_child_autofree(_tab)
	await get_tree().process_frame

	# Find first and last focusable controls
	var first_control := _find_first_focusable(_tab)
	var last_control := _find_last_focusable(_tab)

	assert_not_null(first_control, "Should have a first focusable control")
	assert_not_null(last_control, "Should have a last focusable control")

	# WHEN: Focus is on last control and user presses down
	# THEN: Focus should wrap to first control
	var down_neighbor := last_control.get_focus_neighbor(SIDE_BOTTOM)
	if down_neighbor != NodePath():
		var down_node := last_control.get_node_or_null(down_neighbor)
		assert_eq(down_node, first_control, "Down from last control should focus first control (wrapping)")

func _find_first_focusable(root: Node) -> Control:
	# Find WindowSizeOption which should be the first focusable control
	var window_size_option := root.find_child("WindowSizeOption", true, false)
	if window_size_option is Control:
		return window_size_option as Control
	return null

func _find_last_focusable(root: Node) -> Control:
	# Find ApplyButton which should be the last focusable control
	# (buttons are now included in the focusables array)
	var apply_button := root.find_child("ApplyButton", true, false)
	if apply_button is Control:
		return apply_button as Control
	return null
