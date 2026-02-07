extends GutTest

# TDD: Test window centering uses usable rect instead of full screen (H2)
# Bug: Window centering ignores taskbar/dock - can position behind OS UI

const U_DISPLAY_WINDOW_APPLIER := preload("res://scripts/managers/helpers/display/u_display_window_applier.gd")

var _applier: RefCounted
var _mock_window_ops: MockWindowOps

class MockWindowOps extends RefCounted:
	var last_window_position: Vector2i = Vector2i.ZERO
	var last_window_size: Vector2i = Vector2i.ZERO
	var screen_size: Vector2i = Vector2i(2560, 1440)
	var usable_rect: Rect2i = Rect2i(0, 25, 2560, 1365)  # macOS dock takes 50px at bottom

	func is_real_window_backend() -> bool:
		return false

	func is_available() -> bool:
		return true

	func get_backend_name() -> String:
		return "mock"

	func get_os_name() -> String:
		return "macOS"

	func window_set_size(size: Vector2i) -> void:
		last_window_size = size

	func window_set_position(position: Vector2i) -> void:
		last_window_position = position

	func screen_get_size(_screen: int = -1) -> Vector2i:
		return screen_size

	func screen_get_usable_rect(_screen: int) -> Rect2i:
		return usable_rect

	func window_get_mode() -> int:
		return 0  # WINDOW_MODE_WINDOWED

	func window_set_mode(_mode: int) -> void:
		pass

	func window_get_flag(_flag: int) -> bool:
		return false

	func window_set_flag(_flag: int, _enabled: bool) -> void:
		pass

func before_each() -> void:
	_applier = U_DISPLAY_WINDOW_APPLIER.new()
	_applier.initialize(Node.new())
	_mock_window_ops = MockWindowOps.new()
	_applier.set_window_ops(_mock_window_ops)

func after_each() -> void:
	_applier = null
	_mock_window_ops = null

# FAILING TEST: Window should be centered within usable rect, not full screen
func test_window_centered_in_usable_rect() -> void:
	# Window size: 1920x1080
	# Screen size: 2560x1440
	# Usable rect: (0, 25, 2560, 1365) - 25px menu bar, 50px dock
	_applier.call("_apply_window_size_preset_now", "1920x1080")

	var expected_x := (2560 - 1920) / 2  # 320
	var expected_y := (1365 - 1080) / 2 + 25  # 142 + 25 = 167

	assert_eq(
		_mock_window_ops.last_window_position.x,
		expected_x,
		"Window X should be centered within usable width"
	)
	assert_eq(
		_mock_window_ops.last_window_position.y,
		expected_y,
		"Window Y should be centered within usable height (accounting for menu bar offset)"
	)

# Current behavior test (will pass, showing the bug)
func test_current_behavior_uses_full_screen() -> void:
	_applier.call("_apply_window_size_preset_now", "1920x1080")

	# Current implementation uses screen_get_size() not usable_rect
	var current_x := (2560 - 1920) / 2  # 320
	var current_y := (1440 - 1080) / 2  # 180

	# This currently passes, showing window is centered in full screen
	# After fix, this test should fail
	assert_eq(
		_mock_window_ops.last_window_position,
		Vector2i(current_x, current_y),
		"Current implementation centers in full screen (BUG)"
	)

# Edge case: Small window should still be within usable rect
func test_small_window_positioned_in_usable_rect() -> void:
	_applier.call("_apply_window_size_preset_now", "1280x720")

	# Should be within usable rect bounds
	var pos := _mock_window_ops.last_window_position
	var size := _mock_window_ops.last_window_size
	var usable := _mock_window_ops.usable_rect

	assert_true(
		pos.x >= usable.position.x,
		"Window left edge should be >= usable rect left"
	)
	assert_true(
		pos.y >= usable.position.y,
		"Window top edge should be >= usable rect top"
	)
	assert_true(
		pos.x + size.x <= usable.position.x + usable.size.x,
		"Window right edge should be <= usable rect right"
	)
	assert_true(
		pos.y + size.y <= usable.position.y + usable.size.y,
		"Window bottom edge should be <= usable rect bottom"
	)

# Edge case: Windows taskbar at bottom
func test_windows_taskbar_centering() -> void:
	# Simulate Windows with taskbar at bottom
	_mock_window_ops.screen_size = Vector2i(1920, 1080)
	_mock_window_ops.usable_rect = Rect2i(0, 0, 1920, 1040)  # 40px taskbar

	_applier.call("_apply_window_size_preset_now", "1280x720")

	var expected_x := (1920 - 1280) / 2  # 320
	var expected_y := (1040 - 720) / 2  # 160

	assert_eq(
		_mock_window_ops.last_window_position,
		Vector2i(expected_x, expected_y),
		"Window should be centered in usable rect (above taskbar)"
	)
