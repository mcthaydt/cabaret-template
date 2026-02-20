extends "res://scripts/interfaces/i_camera_manager.gd"
class_name MockCameraManager

## Lightweight mock camera manager for VFX tests.
##
## Phase 5 (cleanup_v4): Updated to extend I_CameraManager interface
##
## Records the last shake request without creating cameras or registering services.

var last_offset: Vector2 = Vector2.ZERO
var last_rotation: float = 0.0
var apply_calls: int = 0
var main_camera: Camera3D = null
var shake_sources: Dictionary = {}

func _ready() -> void:
	# Override to skip base setup and ServiceLocator registration.
	pass

func get_main_camera() -> Camera3D:
	return main_camera

func initialize_scene_camera(_scene: Node) -> Camera3D:
	return null

func finalize_blend_to_scene(_new_scene: Node) -> void:
	pass

func apply_shake_offset(offset: Vector2, rotation: float) -> void:
	last_offset = offset
	last_rotation = rotation
	apply_calls += 1

func set_shake_source(source: StringName, offset: Vector2, rotation: float) -> void:
	if source == &"":
		return
	shake_sources[source] = {
		"offset": offset,
		"rotation": rotation,
	}
	last_offset = offset
	last_rotation = rotation
	apply_calls += 1

func clear_shake_source(source: StringName) -> void:
	if source == &"":
		return
	shake_sources.erase(source)
	last_offset = Vector2.ZERO
	last_rotation = 0.0

func reset() -> void:
	last_offset = Vector2.ZERO
	last_rotation = 0.0
	apply_calls = 0
	shake_sources.clear()
