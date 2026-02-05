extends GutTest

const U_DISPLAY_WINDOW_APPLIER := preload("res://scripts/managers/helpers/display/u_display_window_applier.gd")

class ResizeGuardWindowOps:
	extends MockWindowOps

	var ignore_next_resize_if_borderless: bool = false

	func window_set_size(size: Vector2i) -> void:
		if ignore_next_resize_if_borderless and borderless:
			calls.append({"method": "window_set_size", "size": size, "ignored": true})
			ignore_next_resize_if_borderless = false
			return
		super.window_set_size(size)

func _await_frames(frames: int = 2) -> void:
	for _i in range(frames):
		await get_tree().process_frame

func test_windowed_restore_reapplies_size_after_borderless_fullscreen() -> void:
	var applier := U_DISPLAY_WINDOW_APPLIER.new()
	var owner := Node.new()
	add_child_autofree(owner)
	applier.initialize(owner)

	var window_ops := ResizeGuardWindowOps.new()
	window_ops.screen_size = Vector2i(1920, 1080)
	applier.set_window_ops(window_ops)

	applier.apply_settings({
		"window_size_preset": "1280x720",
		"window_mode": "windowed",
		"vsync_enabled": true,
	})
	await _await_frames()

	applier.apply_settings({
		"window_size_preset": "1280x720",
		"window_mode": "borderless",
		"vsync_enabled": true,
	})
	await _await_frames()

	applier.apply_settings({
		"window_size_preset": "1280x720",
		"window_mode": "fullscreen",
		"vsync_enabled": true,
	})
	await _await_frames()

	window_ops.ignore_next_resize_if_borderless = true
	applier.apply_settings({
		"window_size_preset": "1280x720",
		"window_mode": "windowed",
		"vsync_enabled": true,
	})
	await _await_frames(3)

	assert_eq(
		window_ops.window_size,
		Vector2i(1280, 720),
		"Windowed restore should reapply preset size after mode settles"
	)
