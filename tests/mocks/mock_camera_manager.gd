extends M_CameraManager
class_name MockCameraManager

## Lightweight mock camera manager for VFX tests.
##
## Records the last shake request without creating cameras or registering services.

var last_offset: Vector2 = Vector2.ZERO
var last_rotation: float = 0.0
var apply_calls: int = 0

func _ready() -> void:
	# Override to skip base setup and ServiceLocator registration.
	pass

func apply_shake_offset(offset: Vector2, rotation: float) -> void:
	last_offset = offset
	last_rotation = rotation
	apply_calls += 1

func reset() -> void:
	last_offset = Vector2.ZERO
	last_rotation = 0.0
	apply_calls = 0
