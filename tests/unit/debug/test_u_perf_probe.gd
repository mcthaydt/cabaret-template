extends GutTest

const U_PERF_PROBE := preload("res://scripts/utils/debug/u_perf_probe.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")


func before_all() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)  # Force desktop for tests


func after_all() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(-1)
	U_MOBILE_PLATFORM_DETECTOR.set_testing(false)


func test_create_default_disabled() -> void:
	var probe := U_PerfProbe.create("test_probe", false)
	assert_false(probe.is_enabled(), "Probe should be disabled when created with enabled=false")
	probe.start()
	probe.stop()
	# Should be a no-op when disabled - no crash, no accumulation
	assert_eq(probe._sample_count, 0, "Disabled probe should not accumulate samples")


func test_create_enabled() -> void:
	var probe := U_PerfProbe.create("test_probe", true)
	assert_true(probe.is_enabled(), "Probe should be enabled when created with enabled=true")


func test_set_enabled() -> void:
	var probe := U_PerfProbe.create("test_probe", false)
	assert_false(probe.is_enabled())
	probe.set_enabled(true)
	assert_true(probe.is_enabled(), "set_enabled(true) should enable the probe")
	probe.set_enabled(false)
	assert_false(probe.is_enabled(), "set_enabled(false) should disable the probe")


func test_accumulation() -> void:
	var probe := U_PerfProbe.create("test_probe", true, 999.0)  # Long flush interval
	probe.start()
	probe.stop()
	assert_eq(probe._sample_count, 1, "One start/stop should accumulate one sample")
	assert_gt(probe._total_usec, 0, "Total usec should be positive after sampling")
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


func test_reset() -> void:
	var probe := U_PerfProbe.create("test_probe", true, 999.0)
	probe.start()
	probe.stop()
	assert_gt(probe._sample_count, 0)
	probe.reset()
	assert_eq(probe._sample_count, 0, "Reset should clear sample count")
	assert_eq(probe._total_usec, 0, "Reset should clear total_usec")
	assert_eq(probe._max_usec, 0, "Reset should clear max_usec")


func test_flush_timing() -> void:
	var probe := U_PerfProbe.create("test_probe", true, 0.001)  # 1ms flush interval
	probe._last_flush_usec = 0  # Force flush to be overdue
	probe.start()
	probe.stop()
	# After stop, flush should trigger because interval has elapsed
	# Flush resets sample_count, so we can't assert on _sample_count here
	# But we can verify the probe still works after flush
	probe.start()
	probe.stop()
	assert_eq(probe._sample_count, 1, "Probe should work after flush")


func test_disabled_probe_is_zero_cost() -> void:
	var probe := U_PerfProbe.create("test_probe", false)
	# These should all be no-ops
	for i in range(1000):
		probe.start()
		probe.stop()
	assert_eq(probe._sample_count, 0, "Disabled probe should never accumulate samples")
	assert_eq(probe._total_usec, 0, "Disabled probe should never accumulate time")


func test_factory_create_name() -> void:
	var probe := U_PerfProbe.create("MyTestSystem", true)
	assert_eq(probe._name, "MyTestSystem", "Probe name should match factory parameter")