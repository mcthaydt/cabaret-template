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
var last_main_transform: Transform3D = Transform3D.IDENTITY
var apply_main_transform_calls: int = 0
var blend_active: bool = false
var capture_camera_state_calls: int = 0
var blend_cameras_calls: int = 0
var blend_cameras_last_args: Dictionary = {}
var captured_camera_state: Variant = null
var finalize_blend_calls: int = 0
var finalize_blend_last_scene: Node = null
var _camera_blend_tween: Tween = null

func _ready() -> void:
	# Override to skip base setup and ServiceLocator registration.
	pass

func get_main_camera() -> Camera3D:
	return main_camera

func apply_main_camera_transform(transform: Transform3D) -> void:
	last_main_transform = transform
	apply_main_transform_calls += 1

func is_blend_active() -> bool:
	return blend_active

func initialize_scene_camera(_scene: Node) -> Camera3D:
	return null

func finalize_blend_to_scene(new_scene: Node) -> void:
	finalize_blend_calls += 1
	finalize_blend_last_scene = new_scene

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

func capture_camera_state(_scene: Node) -> Variant:
	capture_camera_state_calls += 1
	return captured_camera_state

func blend_cameras(_old_scene: Node, new_scene: Node, duration: float, old_state: Variant = null) -> void:
	blend_cameras_calls += 1
	blend_cameras_last_args = {
		"new_scene": new_scene,
		"duration": duration,
		"old_state": old_state,
	}

func reset() -> void:
	last_offset = Vector2.ZERO
	last_rotation = 0.0
	apply_calls = 0
	shake_sources.clear()
	last_main_transform = Transform3D.IDENTITY
	apply_main_transform_calls = 0
	blend_active = false
	capture_camera_state_calls = 0
	blend_cameras_calls = 0
	blend_cameras_last_args = {}
	captured_camera_state = null
	finalize_blend_calls = 0
	finalize_blend_last_scene = null
	_camera_blend_tween = null
