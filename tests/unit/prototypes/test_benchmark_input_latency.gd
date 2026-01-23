extends GutTest

const BenchmarkInputLatency := preload("res://tests/prototypes/benchmark_input_latency.gd")

func test_keyboard_latency_records_sample_under_target() -> void:
	var mock_time := MockTimeProvider.new([1_000, 15_000])
	var benchmark := BenchmarkInputLatency.new(Callable(mock_time, "next"))
	benchmark.configure_keyboard_binding(StringName("jump"), KEY_SPACE)

	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	benchmark.ingest_input_event(event)
	benchmark.process_frame()

	var summary := benchmark.get_sample_summary(StringName("keyboard:jump"))
	assert_almost_eq(summary.average_ms, 14.0, 0.001)
	assert_true(summary.within_target)

func test_mouse_motion_latency_records_sample() -> void:
	var mock_time := MockTimeProvider.new([0, 12_000])
	var benchmark := BenchmarkInputLatency.new(Callable(mock_time, "next"))
	benchmark.enable_mouse_motion_tracking(true)

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(4, -2)
	benchmark.ingest_input_event(motion)
	benchmark.process_frame()

	var summary := benchmark.get_sample_summary(StringName("mouse:motion"))
	assert_almost_eq(summary.max_ms, 12.0, 0.001)
	assert_true(summary.within_target)

func test_latency_over_budget_is_flagged() -> void:
	var mock_time := MockTimeProvider.new([0, 20_000])
	var benchmark := BenchmarkInputLatency.new(Callable(mock_time, "next"))
	benchmark.enable_mouse_motion_tracking(true)

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(2, 1)
	benchmark.ingest_input_event(motion)
	benchmark.process_frame()

	var summary := benchmark.get_sample_summary(StringName("mouse:motion"))
	assert_almost_eq(summary.max_ms, 20.0, 0.001)
	assert_false(summary.within_target)

func test_overall_summary_combines_devices() -> void:
	var mock_time := MockTimeProvider.new([
		0, 10_000,  # keyboard sample
		11_000, 25_000,  # mouse sample
	])
	var benchmark := BenchmarkInputLatency.new(Callable(mock_time, "next"))
	benchmark.configure_keyboard_binding(StringName("move_left"), KEY_A)
	benchmark.enable_mouse_motion_tracking(true)

	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.physical_keycode = KEY_A
	benchmark.ingest_input_event(key_event)
	benchmark.process_frame()

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(1, 0)
	benchmark.ingest_input_event(motion)
	benchmark.process_frame()

	var overall := benchmark.get_overall_summary()
	assert_eq(overall.sample_count, 2)
	assert_almost_eq(overall.max_ms, 14.0, 0.001)
	assert_true(overall.within_target)

func test_reset_clears_samples_and_bindings() -> void:
	var mock_time := MockTimeProvider.new([0, 5_000])
	var benchmark := BenchmarkInputLatency.new(Callable(mock_time, "next"))
	benchmark.configure_keyboard_binding(StringName("dash"), KEY_SHIFT)

	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.pressed = true
	benchmark.ingest_input_event(event)
	benchmark.process_frame()
	assert_gt(benchmark.get_sample_summary(StringName("keyboard:dash")).max_ms, 0.0)

	benchmark.reset()
	var summary := benchmark.get_sample_summary(StringName("keyboard:dash"))
	assert_true(summary.within_target)
	assert_eq(summary.max_ms, 0.0)

class MockTimeProvider:
	var _values: Array[int]
	var _index: int = 0

	func _init(values: Array[int]) -> void:
		_values = values.duplicate()

	func next() -> int:
		if _index >= _values.size():
			return _values.back()
		var value := _values[_index]
		_index += 1
		return value
