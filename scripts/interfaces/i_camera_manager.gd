extends Node
class_name I_CameraManager

## Minimal interface for M_CameraManager
##
## Phase 5 (cleanup_v4): Created for duck typing cleanup - removes has_method() checks
##
## Implementations:
## - M_CameraManager (production)
## - MockCameraManager (testing)

## Get the currently registered main camera
##
## @return Camera3D: The main camera, or null if not registered
func get_main_camera() -> Camera3D:
	push_error("I_CameraManager.get_main_camera not implemented")
	return null

## Initialize and find the camera in a scene
##
## Finds camera in the scene subtree and registers it as main camera.
## UI scenes may not have cameras, so returns null gracefully.
##
## @param _scene: Scene to find camera in
## @return Camera3D: Camera if found, null otherwise
func initialize_scene_camera(_scene: Node) -> Camera3D:
	push_error("I_CameraManager.initialize_scene_camera not implemented")
	return null

## Force finalize camera blend to the camera found in the given scene
##
## Used to ensure the transition camera is deactivated and the new
## scene camera is made current. Called as a safety net when timing
## differences prevent the tween's finished signal from firing.
##
## @param _new_scene: Scene to finalize blend to
func finalize_blend_to_scene(_new_scene: Node) -> void:
	push_error("I_CameraManager.finalize_blend_to_scene not implemented")

## Apply screen shake offset and rotation
##
## Converts 2D screen-space offset to 3D camera-relative offset and applies
## rotation around the Z axis (roll). The shake is applied to the shake parent
## node, not the camera directly, to prevent gimbal lock.
##
## @param _offset: 2D screen-space offset in pixels (X=horizontal, Y=vertical)
## @param _rotation: Z-axis rotation in radians (camera roll)
func apply_shake_offset(_offset: Vector2, _rotation: float) -> void:
	push_error("I_CameraManager.apply_shake_offset not implemented")
