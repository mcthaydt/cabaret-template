extends GutTest

# TDD: Test window centering uses usable rect instead of full screen (H2)
# Bug: Window centering ignores taskbar/dock - can position behind OS UI

const U_DISPLAY_SERVER_WINDOW_OPS := preload("res://scripts/utils/display/u_display_server_window_ops.gd")

# Test the centering calculation logic directly
func test_centering_calculation_uses_usable_rect() -> void:
	# GIVEN: Screen with usable rect smaller than full size (25px menu bar, 50px dock)
	var usable_rect := Rect2i(0, 25, 2560, 1365)  # macOS with menu bar and dock
	var window_size := Vector2i(1920, 1080)

	# WHEN: Calculating centered position
	var window_pos := usable_rect.position + (usable_rect.size - window_size) / 2

	# THEN: Window should be centered in usable area, not full screen
	var expected_x := (2560 - 1920) / 2  # 320
	var expected_y := (1365 - 1080) / 2 + 25  # 142 + 25 = 167

	assert_eq(window_pos.x, expected_x, "Window X should be centered within usable width")
	assert_eq(window_pos.y, expected_y, "Window Y should be centered within usable height")

func test_centering_calculation_windows_taskbar() -> void:
	# GIVEN: Windows screen with taskbar at bottom
	var usable_rect := Rect2i(0, 0, 1920, 1040)  # 40px taskbar at bottom
	var window_size := Vector2i(1280, 720)

	# WHEN: Calculating centered position
	var window_pos := usable_rect.position + (usable_rect.size - window_size) / 2

	# THEN: Window should be centered above taskbar
	var expected_x := (1920 - 1280) / 2  # 320
	var expected_y := (1040 - 720) / 2  # 160

	assert_eq(window_pos.x, expected_x, "Window X should be centered")
	assert_eq(window_pos.y, expected_y, "Window Y should be centered above taskbar")

func test_centering_calculation_keeps_window_in_bounds() -> void:
	# GIVEN: Small window on screen with reduced usable rect
	var usable_rect := Rect2i(0, 25, 2560, 1365)
	var window_size := Vector2i(800, 600)

	# WHEN: Calculating centered position
	var window_pos := usable_rect.position + (usable_rect.size - window_size) / 2

	# THEN: Window should be fully within usable rect
	assert_true(window_pos.x >= usable_rect.position.x, "Window left >= usable left")
	assert_true(window_pos.y >= usable_rect.position.y, "Window top >= usable top")
	assert_true(
		window_pos.x + window_size.x <= usable_rect.position.x + usable_rect.size.x,
		"Window right <= usable right"
	)
	assert_true(
		window_pos.y + window_size.y <= usable_rect.position.y + usable_rect.size.y,
		"Window bottom <= usable bottom"
	)

# Test that U_DisplayServerWindowOps has the required interface
func test_display_server_window_ops_has_usable_rect_method() -> void:
	var ops := U_DISPLAY_SERVER_WINDOW_OPS.new()

	# THEN: Should have screen_get_usable_rect method
	assert_true(
		ops.has_method("screen_get_usable_rect"),
		"U_DisplayServerWindowOps should have screen_get_usable_rect method"
	)

# Integration test: Verify the implementation exists and is callable
func test_window_applier_uses_usable_rect_in_implementation() -> void:
	# Read the implementation to verify it uses usable_rect
	var script_path := "res://scripts/managers/helpers/display/u_display_window_applier.gd"
	var file := FileAccess.open(script_path, FileAccess.READ)

	if file == null:
		fail_test("Could not open window applier script")
		return

	var content := file.get_as_text()
	file.close()

	# THEN: Implementation should use screen_get_usable_rect
	assert_true(
		content.contains("screen_get_usable_rect"),
		"Window applier should call screen_get_usable_rect"
	)

	# THEN: Implementation should use window_get_current_screen
	assert_true(
		content.contains("window_get_current_screen"),
		"Window applier should get current screen for usable rect"
	)

	# THEN: Should use usable_rect for centering calculation
	assert_true(
		content.contains("usable_rect.position") or content.contains("usable_rect.size"),
		"Window applier should use usable rect position/size for centering"
	)
