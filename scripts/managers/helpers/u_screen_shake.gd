class_name U_ScreenShake
extends RefCounted

# Screen shake helper with quadratic falloff and noise-based offset/rotation
# Used by M_VFXManager to apply camera shake based on trauma

# Maximum screen offset in pixels (X, Y)
var max_offset := Vector2(10.0, 8.0)

# Maximum camera rotation in radians
var max_rotation := 0.05

# Speed at which noise advances over time (higher = faster shake variation)
var noise_speed := 50.0

# FastNoiseLite instance for randomized shake values
var _noise: FastNoiseLite

# Accumulated time for noise sampling
var _time: float = 0.0

# Testing hooks (negative values disable)
var _test_seed: int = -1
var _test_time: float = -1.0


func _init(config: Resource = null) -> void:
	if config != null:
		max_offset = config.max_offset
		max_rotation = config.max_rotation
		noise_speed = config.noise_speed
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.frequency = 1.0


## Calculate screen shake offset and rotation based on trauma level
##
## @param trauma: Current trauma level (0.0-1.0), decays over time
## @param settings_multiplier: User settings multiplier (0.0-2.0), affects intensity
## @param delta: Time delta in seconds
## @return U_ShakeResult containing offset (Vector2) and rotation (float)
func calculate_shake(trauma: float, settings_multiplier: float, delta: float):
	# Advance or override noise time for variation
	if _test_time >= 0.0:
		_time = _test_time
	else:
		_time += delta * noise_speed

	# Quadratic falloff: trauma^2 provides smoother, more natural-feeling shake decay
	var shake_amount := trauma * trauma

	# Calculate 2D screen offset using different noise samples for X and Y
	var offset := Vector2(
		max_offset.x * shake_amount * _noise.get_noise_1d(_time),
		max_offset.y * shake_amount * _noise.get_noise_1d(_time + 100.0)
	) * settings_multiplier

	# Calculate camera rotation using a third noise sample
	var rotation_noise := _noise.get_noise_1d(_time + 200.0)
	# Guard against rare 0 output by sampling an alternate time to ensure a non-zero shake
	if abs(rotation_noise) < 0.0001 and shake_amount > 0.0:
		rotation_noise = _noise.get_noise_1d(_time + 201.2345)
	var rotation := max_rotation * shake_amount * rotation_noise * settings_multiplier

	return U_ShakeResult.new(offset, rotation)


func set_noise_seed_for_testing(noise_seed: int) -> void:
	_test_seed = noise_seed
	if noise_seed >= 0:
		_noise.seed = noise_seed


func set_sample_time_for_testing(time: float) -> void:
	_test_time = time


func get_sample_time() -> float:
	return _time
