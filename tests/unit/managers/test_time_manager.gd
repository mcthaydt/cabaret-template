extends GutTest

const U_PAUSE_SYSTEM := preload("res://scripts/managers/helpers/time/u_pause_system.gd")


func test_initial_state_not_paused() -> void:
	var pause_system := U_PAUSE_SYSTEM.new()

	assert_false(pause_system.compute_is_paused(), "Fresh pause system should not be paused")

func test_request_pause_single_channel() -> void:
	var pause_system := U_PAUSE_SYSTEM.new()

	pause_system.request_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)

	assert_true(pause_system.compute_is_paused(), "Requesting one channel should pause")

func test_release_pause_single_channel() -> void:
	var pause_system := U_PAUSE_SYSTEM.new()

	pause_system.request_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)
	pause_system.release_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)

	assert_false(pause_system.compute_is_paused(), "Releasing requested channel should unpause")

func test_ref_counting() -> void:
	var pause_system := U_PAUSE_SYSTEM.new()

	pause_system.request_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)
	pause_system.request_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)
	pause_system.release_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)

	assert_true(pause_system.compute_is_paused(), "One remaining ref should stay paused")

	pause_system.release_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)

	assert_false(pause_system.compute_is_paused(), "Releasing final ref should unpause")

func test_multiple_channels() -> void:
	var pause_system := U_PAUSE_SYSTEM.new()

	pause_system.request_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)
	pause_system.request_pause(U_PAUSE_SYSTEM.CHANNEL_DEBUG)
	pause_system.release_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)

	assert_true(pause_system.compute_is_paused(), "Should remain paused while another channel is active")

func test_is_channel_paused() -> void:
	var pause_system := U_PAUSE_SYSTEM.new()

	pause_system.request_pause(U_PAUSE_SYSTEM.CHANNEL_DEBUG)

	assert_true(pause_system.is_channel_paused(U_PAUSE_SYSTEM.CHANNEL_DEBUG), "Requested channel should be paused")
	assert_false(pause_system.is_channel_paused(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE), "Unrequested channel should not be paused")

func test_get_active_channels() -> void:
	var pause_system := U_PAUSE_SYSTEM.new()

	pause_system.request_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)
	pause_system.request_pause(U_PAUSE_SYSTEM.CHANNEL_SYSTEM)
	var active_channels: Array[StringName] = pause_system.get_active_channels()

	assert_eq(active_channels.size(), 2, "Only active channels should be returned")
	assert_true(active_channels.has(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE), "Cutscene channel should be listed")
	assert_true(active_channels.has(U_PAUSE_SYSTEM.CHANNEL_SYSTEM), "System channel should be listed")

func test_derive_from_overlay_state_pauses() -> void:
	var pause_system := U_PAUSE_SYSTEM.new()

	pause_system.derive_pause_from_overlay_state(1)

	assert_true(pause_system.is_channel_paused(U_PAUSE_SYSTEM.CHANNEL_UI), "Overlay count > 0 should activate UI channel")
	assert_true(pause_system.compute_is_paused(), "Overlay-driven UI channel should pause")

func test_derive_from_overlay_state_unpauses() -> void:
	var pause_system := U_PAUSE_SYSTEM.new()

	pause_system.derive_pause_from_overlay_state(1)
	pause_system.derive_pause_from_overlay_state(0)

	assert_false(pause_system.is_channel_paused(U_PAUSE_SYSTEM.CHANNEL_UI), "Overlay count 0 should clear UI channel")
	assert_false(pause_system.compute_is_paused(), "No active channels should unpause")

func test_release_below_zero_clamps_and_ui_manual_noop() -> void:
	var pause_system := U_PAUSE_SYSTEM.new()

	pause_system.release_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)
	pause_system.release_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)
	assert_false(pause_system.compute_is_paused(), "Release without request should remain unpaused")

	pause_system.request_pause(U_PAUSE_SYSTEM.CHANNEL_UI)
	assert_false(pause_system.is_channel_paused(U_PAUSE_SYSTEM.CHANNEL_UI), "Manual UI request should be ignored")

	pause_system.derive_pause_from_overlay_state(1)
	assert_true(pause_system.is_channel_paused(U_PAUSE_SYSTEM.CHANNEL_UI), "Derive should control UI channel")

	pause_system.release_pause(U_PAUSE_SYSTEM.CHANNEL_UI)
	assert_true(pause_system.is_channel_paused(U_PAUSE_SYSTEM.CHANNEL_UI), "Manual UI release should be ignored")

	pause_system.derive_pause_from_overlay_state(0)
	assert_false(pause_system.is_channel_paused(U_PAUSE_SYSTEM.CHANNEL_UI), "Derive should clear UI channel")
