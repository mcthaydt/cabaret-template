extends GutTest

## Tests for U_PerfProbe mobile performance diagnostic utility.

const U_PERF_PROBE_SCRIPT := preload("res://scripts/utils/debug/u_perf_probe.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")

var _original_mobile_override: int = 0
var _original_testing: bool = false


func before_all() -> void:
	_original_mobile_override = U_MOBILE_PLATFORM_DETECTOR._mobile_override
	_original_testing = U_MOBILE_PLATFORM_DETECTOR._testing


func before_each() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)  # Force mobile


func after_each() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(_original_mobile_override)
	if not _original_testing:
		U_MOBILE_PLATFORM_DETECTOR.set_testing(false)


func after_all() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(_original_mobile_override)
	U_MOBILE_PLATFORM_DETECTOR.set_testing(_original_testing)


func test_begin_returns_nonzero_on_mobile() -> void:
	var probe = U_PERF_PROBE_SCRIPT.new("test_probe", 10)
	var start: int = probe.begin()
	assert_ne(start, 0, "begin() should return nonzero ticks on mobile")
	probe.end(start)


func test_begin_returns_zero_when_not_mobile() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)  # Force desktop
	var probe = U_PERF_PROBE_SCRIPT.new("test_probe", 10)
	var start: int = probe.begin()
	assert_eq(start, 0, "begin() should return 0 on desktop")


func test_end_accumulates_time() -> void:
	var probe = U_PERF_PROBE_SCRIPT.new("test_probe", 100)
	var start: int = probe.begin()
	probe.end(start)
	assert_gt(probe._count, 0, "Should have accumulated at least one measurement")
	assert_gt(probe._total_usec, 0, "Should have accumulated some time")


func test_end_is_noop_with_zero_start() -> void:
	var probe = U_PERF_PROBE_SCRIPT.new("test_probe", 100)
	probe.end(0)  # Should be a no-op
	assert_eq(probe._count, 0, "Should not accumulate with zero start ticks")


func test_max_tracks_maximum() -> void:
	var probe = U_PERF_PROBE_SCRIPT.new("test_probe", 100)
	var start1: int = probe.begin()
	probe.end(start1)
	var start2: int = probe.begin()
	probe.end(start2)
	# max_usec should be >= total_usec / count (at minimum)
	assert_gt(probe._max_usec, 0, "Should track max time")


func test_tick_and_maybe_log_resets_after_interval() -> void:
	var probe = U_PERF_PROBE_SCRIPT.new("test_probe", 3)  # Log every 3 frames
	var start: int = probe.begin()
	probe.end(start)
	probe.tick_and_maybe_log()  # Frame 1
	probe.tick_and_maybe_log()  # Frame 2
	probe.tick_and_maybe_log()  # Frame 3 - should log and reset
	assert_eq(probe._count, 0, "Count should reset after logging")
	assert_eq(probe._total_usec, 0, "Total should reset after logging")
	assert_eq(probe._max_usec, 0, "Max should reset after logging")


func test_tick_and_maybe_log_no_log_without_data() -> void:
	var probe = U_PERF_PROBE_SCRIPT.new("test_probe", 2)
	# No begin/end calls, just tick
	probe.tick_and_maybe_log()  # Frame 1
	probe.tick_and_maybe_log()  # Frame 2 - should not crash, count is 0
	assert_eq(probe._count, 0, "Should remain zero if no measurements taken")


func test_reset_clears_all_state() -> void:
	var probe = U_PERF_PROBE_SCRIPT.new("test_probe", 100)
	var start: int = probe.begin()
	probe.end(start)
	probe.tick_and_maybe_log()
	probe.reset()
	assert_eq(probe._count, 0, "Count should be 0 after reset")
	assert_eq(probe._total_usec, 0, "Total should be 0 after reset")
	assert_eq(probe._max_usec, 0, "Max should be 0 after reset")
	assert_eq(probe._frame_counter, 0, "Frame counter should be 0 after reset")


func test_is_active_on_mobile() -> void:
	var probe = U_PERF_PROBE_SCRIPT.new("test_probe", 10)
	assert_true(probe.is_active(), "Probe should be active on mobile")


func test_is_not_active_on_desktop() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)  # Force desktop
	var probe = U_PERF_PROBE_SCRIPT.new("test_probe", 10)
	assert_false(probe.is_active(), "Probe should not be active on desktop")