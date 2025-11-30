extends GutTest

## Test suite for analog stick repeat/echo behavior
##
## Verifies that analog stick UI navigation repeats like keyboard/D-pad:
## 1. Immediate trigger when crossing deadzone
## 2. Initial delay (~500ms) before first repeat
## 3. Continuous repeat (~50ms interval) while held
## 4. Stop when released below deadzone

const AnalogStickRepeater = preload("res://scripts/ui/utils/analog_stick_repeater.gd")

const REPEAT_INITIAL_DELAY: float = 0.5  # 500ms
const REPEAT_INTERVAL: float = 0.05      # 50ms

var repeater: AnalogStickRepeater
var navigation_calls: Array[StringName]


func before_each() -> void:
	repeater = AnalogStickRepeater.new()
	navigation_calls = []

	# Set callback to track navigation calls
	repeater.on_navigate = func(direction: StringName) -> void:
		navigation_calls.append(direction)


func after_each() -> void:
	navigation_calls.clear()


## IMMEDIATE TRIGGER TESTS

func test_first_trigger_fires_immediately() -> void:
	# Simulate stick crossing deadzone threshold
	var delta: float = 0.016  # One frame at 60fps

	repeater.update("ui_down", true, delta)

	assert_eq(navigation_calls.size(), 1, "Should trigger immediately on first input")
	assert_eq(navigation_calls[0], StringName("ui_down"))


func test_different_directions_trigger_independently() -> void:
	var delta: float = 0.016

	repeater.update("ui_down", true, delta)
	repeater.update("ui_left", true, delta)

	assert_eq(navigation_calls.size(), 2, "Each direction should trigger independently")
	assert_eq(navigation_calls[0], StringName("ui_down"))
	assert_eq(navigation_calls[1], StringName("ui_left"))


## REPEAT DELAY TESTS

func test_no_repeat_before_initial_delay() -> void:
	var delta: float = 0.016

	# First trigger
	repeater.update("ui_down", true, delta)
	navigation_calls.clear()

	# Simulate 300ms (not enough for initial delay)
	for i in range(18):  # 18 frames * 16ms ≈ 288ms
		repeater.update("ui_down", true, delta)

	assert_eq(navigation_calls.size(), 0,
		"Should not repeat before initial delay (~500ms)")


func test_first_repeat_after_initial_delay() -> void:
	var delta: float = 0.016

	# First trigger
	repeater.update("ui_down", true, delta)
	navigation_calls.clear()

	# Simulate 500ms+
	for i in range(32):  # 32 frames * 16ms ≈ 512ms
		repeater.update("ui_down", true, delta)

	assert_gt(navigation_calls.size(), 0,
		"Should repeat after initial delay (~500ms)")


## REPEAT RATE TESTS

func test_continuous_repeat_at_interval() -> void:
	var delta: float = 0.016

	# First trigger
	repeater.update("ui_down", true, delta)
	navigation_calls.clear()

	# Simulate 1 second of holding (after initial delay passes)
	var total_time: float = 0.0
	var frame_count: int = 0

	while total_time < 1.0:
		repeater.update("ui_down", true, delta)
		total_time += delta
		frame_count += 1

	# After 500ms delay, we have 500ms of repeating
	# At 50ms intervals, that's ~10 repeats (allow for timing precision)
	assert_gte(navigation_calls.size(), 8,
		"Should have multiple repeats (expected 8-10)")
	assert_lte(navigation_calls.size(), 11,
		"Repeat count should be reasonable (8-10, not way more)")


## RELEASE TESTS

func test_stops_when_released() -> void:
	var delta: float = 0.016

	# First trigger
	repeater.update("ui_down", true, delta)
	navigation_calls.clear()

	# Hold for initial delay
	for i in range(32):
		repeater.update("ui_down", true, delta)

	var repeat_count := navigation_calls.size()
	navigation_calls.clear()

	# Release (below deadzone)
	repeater.update("ui_down", false, delta)

	# Continue updating (should not trigger anymore)
	for i in range(10):
		repeater.update("ui_down", false, delta)

	assert_eq(navigation_calls.size(), 0,
		"Should stop repeating after release")


func test_reset_on_direction_change() -> void:
	var delta: float = 0.016

	# Trigger down
	repeater.update("ui_down", true, delta)
	navigation_calls.clear()

	# Wait 300ms (not enough for repeat)
	for i in range(18):
		repeater.update("ui_down", true, delta)

	# Change to up (should reset timer and trigger immediately)
	repeater.update("ui_up", true, delta)

	# The last call should be ui_up
	assert_eq(navigation_calls[-1], StringName("ui_up"),
		"Direction change should trigger immediately")


## EDGE CASE TESTS

func test_rapid_on_off_triggers_each_time() -> void:
	var delta: float = 0.016

	# Trigger, release, trigger, release
	repeater.update("ui_down", true, delta)
	repeater.update("ui_down", false, delta)
	repeater.update("ui_down", true, delta)
	repeater.update("ui_down", false, delta)
	repeater.update("ui_down", true, delta)

	assert_eq(navigation_calls.size(), 3,
		"Each press should trigger (no debouncing for intentional presses)")


func test_multiple_directions_held_simultaneously() -> void:
	var delta: float = 0.016

	# Hold down and right simultaneously
	repeater.update("ui_down", true, delta)
	repeater.update("ui_right", true, delta)
	navigation_calls.clear()

	# Wait for initial delay on both
	for i in range(32):
		repeater.update("ui_down", true, delta)
		repeater.update("ui_right", true, delta)

	# Both should have repeated
	var down_count := navigation_calls.count(StringName("ui_down"))
	var right_count := navigation_calls.count(StringName("ui_right"))

	assert_gt(down_count, 0, "Down should repeat")
	assert_gt(right_count, 0, "Right should repeat")
