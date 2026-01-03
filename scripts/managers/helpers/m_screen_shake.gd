class_name M_ScreenShake
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


func _init() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.frequency = 1.0


## Calculate screen shake offset and rotation based on trauma level
##
## @param trauma: Current trauma level (0.0-1.0), decays over time
## @param settings_multiplier: User settings multiplier (0.0-2.0), affects intensity
## @param delta: Time delta in seconds
## @return Dictionary with "offset" (Vector2) and "rotation" (float) keys
func calculate_shake(trauma: float, settings_multiplier: float, delta: float) -> Dictionary:
	# Advance noise time for variation
	_time += delta * noise_speed

	# Quadratic falloff: trauma^2 provides smoother, more natural-feeling shake decay
	var shake_amount := trauma * trauma

	# Calculate 2D screen offset using different noise samples for X and Y
	var offset := Vector2(
		max_offset.x * shake_amount * _noise.get_noise_1d(_time),
		max_offset.y * shake_amount * _noise.get_noise_1d(_time + 100.0)
	) * settings_multiplier

	# Calculate camera rotation using a third noise sample
	var rotation := max_rotation * shake_amount * _noise.get_noise_1d(_time + 200.0) * settings_multiplier

	return {"offset": offset, "rotation": rotation}
