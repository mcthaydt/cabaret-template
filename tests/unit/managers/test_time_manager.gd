extends GutTest

const U_PAUSE_SYSTEM := preload("res://scripts/managers/helpers/time/u_pause_system.gd")
const U_TIMESCALE_CONTROLLER := preload("res://scripts/managers/helpers/time/u_timescale_controller.gd")
const M_TIME_MANAGER := preload("res://scripts/managers/m_time_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _time_manager: Node = null
var _store: Node = null
var _overlay_stack: CanvasLayer = null


func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_time_manager = null
	_store = null
	_overlay_stack = null
	get_tree().paused = false

func after_each() -> void:
	get_tree().paused = false
	if _overlay_stack and is_instance_valid(_overlay_stack):
		_overlay_stack.free()
	U_SERVICE_LOCATOR.clear()
	_time_manager = null
	_store = null
	_overlay_stack = null


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

func test_default_timescale() -> void:
	var timescale_controller := U_TIMESCALE_CONTROLLER.new()

	assert_eq(timescale_controller.get_timescale(), 1.0, "Default timescale should be 1.0")

func test_set_timescale() -> void:
	var timescale_controller := U_TIMESCALE_CONTROLLER.new()

	timescale_controller.set_timescale(0.5)

	assert_almost_eq(timescale_controller.get_timescale(), 0.5, 0.0001,
		"Setting timescale should update value")

func test_timescale_clamp_lower() -> void:
	var timescale_controller := U_TIMESCALE_CONTROLLER.new()

	timescale_controller.set_timescale(0.0)

	assert_almost_eq(timescale_controller.get_timescale(), 0.01, 0.0001,
		"Timescale should clamp to minimum")

func test_timescale_clamp_upper() -> void:
	var timescale_controller := U_TIMESCALE_CONTROLLER.new()

	timescale_controller.set_timescale(100.0)

	assert_almost_eq(timescale_controller.get_timescale(), 10.0, 0.0001,
		"Timescale should clamp to maximum")

func test_scaled_delta() -> void:
	var timescale_controller := U_TIMESCALE_CONTROLLER.new()

	timescale_controller.set_timescale(0.5)
	var scaled_delta: float = timescale_controller.get_scaled_delta(1.0)

	assert_almost_eq(scaled_delta, 0.5, 0.0001,
		"Scaled delta should apply current timescale")

func test_scaled_delta_default() -> void:
	var timescale_controller := U_TIMESCALE_CONTROLLER.new()
	var scaled_delta: float = timescale_controller.get_scaled_delta(0.016)

	assert_almost_eq(scaled_delta, 0.016, 0.0001,
		"Scaled delta should match raw delta at default timescale")

func test_get_scaled_delta_default() -> void:
	await _setup_time_manager_with_store()
	var raw_delta: float = 0.016

	assert_almost_eq(_time_manager.get_scaled_delta(raw_delta), raw_delta, 0.0001,
		"M_TimeManager should return raw delta at default timescale")

func test_set_timescale_scales_delta_and_emits_signal() -> void:
	await _setup_time_manager_with_store()
	watch_signals(_time_manager)

	_time_manager.set_timescale(0.5)

	assert_almost_eq(_time_manager.get_timescale(), 0.5, 0.0001,
		"M_TimeManager should expose clamped timescale")
	assert_almost_eq(_time_manager.get_scaled_delta(1.0), 0.5, 0.0001,
		"M_TimeManager should scale delta by timescale")
	assert_signal_emit_count(_time_manager, "timescale_changed", 1,
		"timescale_changed should emit when timescale is updated")

func test_backward_compat_pause_manager_lookup() -> void:
	await _setup_time_manager_with_store()
	U_SERVICE_LOCATOR.register(StringName("pause_manager"), _time_manager)

	var pause_service := U_SERVICE_LOCATOR.get_service(StringName("pause_manager"))
	assert_eq(pause_service, _time_manager, "pause_manager service should resolve to M_TimeManager")

func test_is_paused_false_initially() -> void:
	await _setup_time_manager_with_store()

	assert_false(_time_manager.is_paused(), "Time manager should start unpaused")

func test_request_release_pause() -> void:
	await _setup_time_manager_with_store()

	_time_manager.request_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)
	assert_true(_time_manager.is_paused(), "Requesting pause should set paused state")

	_time_manager.release_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)
	assert_false(_time_manager.is_paused(), "Releasing pause should clear paused state")

func test_pause_state_changed_signal() -> void:
	await _setup_time_manager_with_store()
	watch_signals(_time_manager)

	_time_manager.request_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)
	_time_manager.release_pause(U_PAUSE_SYSTEM.CHANNEL_CUTSCENE)

	assert_signal_emit_count(_time_manager, "pause_state_changed", 2,
		"pause_state_changed should emit on pause and unpause transitions")

func _setup_time_manager_with_store(scene_state: Dictionary = {}) -> void:
	_store = MOCK_STATE_STORE.new()
	_store.set_slice(StringName("scene"), scene_state)
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	_overlay_stack = CanvasLayer.new()
	_overlay_stack.name = "UIOverlayStack"
	add_child_autofree(_overlay_stack)

	_time_manager = M_TIME_MANAGER.new()
	add_child_autofree(_time_manager)
	await get_tree().process_frame
