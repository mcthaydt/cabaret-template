extends RefCounted
class_name U_WorldClock

const MINUTES_PER_DAY := 1440.0
const DEFAULT_SUNRISE_HOUR := 6
const DEFAULT_SUNSET_HOUR := 18

var total_minutes: float = 480.0
var day_count: int = 1
var minutes_per_real_second: float = 1.0

var sunrise_hour: int = DEFAULT_SUNRISE_HOUR
var sunset_hour: int = DEFAULT_SUNSET_HOUR

var on_minute_changed: Callable = Callable()
var on_hour_changed: Callable = Callable()

func advance(scaled_delta: float) -> void:
	var prev_minutes_today: int = int(fmod(total_minutes, MINUTES_PER_DAY))
	total_minutes += minutes_per_real_second * scaled_delta

	while total_minutes >= float(day_count) * MINUTES_PER_DAY:
		day_count += 1

	var new_minutes_today: int = int(fmod(total_minutes, MINUTES_PER_DAY))

	if new_minutes_today != prev_minutes_today:
		if on_minute_changed.is_valid():
			on_minute_changed.call(new_minutes_today % 60)

		var prev_hour: int = int(prev_minutes_today / 60.0)
		var new_hour: int = int(new_minutes_today / 60.0)
		if new_hour != prev_hour and on_hour_changed.is_valid():
			on_hour_changed.call(new_hour)

func get_time() -> Dictionary:
	var minutes_today: int = int(fmod(total_minutes, MINUTES_PER_DAY))
	return {
		"hour": int(minutes_today / 60.0),
		"minute": minutes_today % 60,
		"total_minutes": total_minutes,
		"day_count": day_count,
	}

func set_time(hour: int, minute: int) -> void:
	var current_day_base: float = float(day_count - 1) * MINUTES_PER_DAY
	total_minutes = current_day_base + float(clampi(hour, 0, 23) * 60 + clampi(minute, 0, 59))

func set_state(next_total_minutes: float, next_day_count: int, next_speed: float) -> void:
	total_minutes = maxf(next_total_minutes, 0.0)
	day_count = maxi(next_day_count, 1)
	var minimum_total_for_day: float = float(day_count - 1) * MINUTES_PER_DAY
	if total_minutes < minimum_total_for_day:
		day_count = int(total_minutes / MINUTES_PER_DAY) + 1
	minutes_per_real_second = maxf(next_speed, 0.0)

func set_speed(mps: float) -> void:
	minutes_per_real_second = maxf(mps, 0.0)

func is_daytime() -> bool:
	var minutes_today: int = int(fmod(total_minutes, MINUTES_PER_DAY))
	var hour: int = int(minutes_today / 60.0)
	return hour >= sunrise_hour and hour < sunset_hour
