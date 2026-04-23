extends GutTest

const U_PERF_PROBE := preload("res://scripts/utils/debug/u_perf_probe.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")


func before_all() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)  # Force desktop for tests


func after_all() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(-1)
	U_MOBILE_PLATFORM_DETECTOR.set_testing(false)


func test_create_default_enabled_on_mobile() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	var probe := U_PerfProbe.create("test_probe")
	assert_true(probe.is_enabled(), "create() default should auto-enable probe on mobile")


func test_create_default_disabled_on_desktop() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)
	var probe := U_PerfProbe.create("test_probe")
	assert_false(probe.is_enabled(), "create() default should stay disabled on desktop")


func test_explicit_enabled_override_still_wins_on_desktop() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)
	var probe := U_PerfProbe.create("test_probe", true)
	assert_true(probe.is_enabled(), "Explicit enabled=true should override desktop default")


func test_explicit_disabled_stays_zero_cost() -> void:
	var probe := U_PerfProbe.create("test_probe", false)
	for i in range(50):
		probe.start()
		probe.stop()
	assert_eq(probe._sample_count, 0, "Disabled probe should never accumulate samples")
	assert_eq(probe._total_usec, 0, "Disabled probe should never accumulate time")
	assert_false(probe._running, "Disabled probe should not remain in running state")


func test_start_stop_accumulates_sample_and_updates_running_state() -> void:
	var probe := U_PerfProbe.create("test_probe", true, 999.0)
	assert_false(probe._running)
	probe.start()
	assert_true(probe._running)
	probe.stop()
	assert_false(probe._running)
	assert_eq(probe._sample_count, 1, "One start/stop should accumulate one sample")
	assert_gt(probe._total_usec, 0, "Total usec should be positive after sampling")
	assert_gt(probe._min_usec, 0, "Min usec should be positive after sampling")
	assert_gt(probe._max_usec, 0, "Max usec should be positive after sampling")


func test_min_max_tracking() -> void:
	var probe := U_PerfProbe.create("test_probe", true, 999.0)
	# First sample
	probe.start()
	probe.stop()
	var first_min: int = probe._min_usec
	var first_max: int = probe._max_usec

	# Add a small delay and second sample
	OS.delay_usec(1000)  # 1ms
	probe.start()
	probe.stop()
	assert_lte(probe._min_usec, first_min, "Min should be <= first sample")
	assert_gte(probe._max_usec, first_max, "Max should be >= first sample")
	assert_eq(probe._sample_count, 2, "Two stop calls should accumulate two samples")


func test_reset_clears_accumulators_and_running_state() -> void:
	var probe := U_PerfProbe.create("test_probe", true, 999.0)
	probe.start()
	assert_true(probe._running)
	probe.stop()
	assert_gt(probe._sample_count, 0)
	probe.reset()
	assert_eq(probe._sample_count, 0, "Reset should clear sample count")
	assert_eq(probe._total_usec, 0, "Reset should clear total_usec")
	assert_eq(probe._min_usec, 9223372036854775807, "Reset should restore min sentinel")
	assert_eq(probe._max_usec, 0, "Reset should clear max_usec")
	assert_false(probe._running, "Reset should clear running state")


func test_default_flush_interval_is_two_seconds() -> void:
	var probe := U_PerfProbe.create("test_probe", true)
	assert_eq(probe._flush_interval_usec, 2_000_000, "Default flush interval should be 2 seconds")


func test_flush_triggers_when_interval_elapsed() -> void:
	var probe := U_PerfProbe.create("test_probe", true, 0.001)  # 1ms
	probe._last_flush_usec = 0  # Force flush to be overdue
	probe.start()
	probe.stop()
	assert_eq(probe._sample_count, 0, "Flush should reset sample_count")
	assert_eq(probe._total_usec, 0, "Flush should reset total_usec")
	assert_eq(probe._max_usec, 0, "Flush should reset max_usec")
	assert_gt(probe._last_flush_usec, 0, "Flush should update last_flush_usec")


func test_set_enabled_toggles_runtime_state() -> void:
	var probe := U_PerfProbe.create("test_probe", false)
	assert_false(probe.is_enabled())
	probe.set_enabled(true)
	assert_true(probe.is_enabled(), "set_enabled(true) should enable the probe")
	probe.start()
	assert_true(probe._running)
	probe.set_enabled(false)
	assert_false(probe.is_enabled(), "set_enabled(false) should disable the probe")
	assert_false(probe._running, "Disabling should clear running state")


func test_factory_create_name() -> void:
	var probe := U_PerfProbe.create("MyTestSystem", true)
	assert_eq(probe._name, "MyTestSystem", "Probe name should match factory parameter")
