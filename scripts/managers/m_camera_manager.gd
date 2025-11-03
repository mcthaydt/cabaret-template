@icon("res://resources/editor_icons/manager.svg")
class_name M_CameraManager
extends Node

## M_CameraManager - Camera Blending Management (Phase 12.2)
##
## Handles smooth camera blending during scene transitions using Tween interpolation.
## Extracted from M_SceneManager to achieve maximum separation of concerns (3-manager architecture).
##
## Responsibilities:
## - Capture camera state from scenes
## - Create and manage transition camera
## - Blend camera position, rotation, and FOV smoothly
## - Finalize camera handoff to new scene
##
## Integration:
## - Called by M_SceneManager during scene transitions
## - Can be used independently for cinematics, camera shake, cutscenes
##
## Architecture:
## - Scene-based manager (not autoload)
## - Added to "camera_manager" group in _ready()
## - Discovered via get_tree().get_first_node_in_group("camera_manager")

## Camera state capture for blending (Phase 10)
class CameraState:
	var global_position: Vector3
	var global_rotation: Vector3
	var fov: float

	func _init(p_position: Vector3, p_rotation: Vector3, p_fov: float) -> void:
		global_position = p_position
		global_rotation = p_rotation
		fov = p_fov

## Camera blending (Phase 10: T178-T181)
var _transition_camera: Camera3D = null
var _camera_blend_tween: Tween = null
var _camera_blend_duration: float = 0.2  # Match fade transition duration

func _ready() -> void:
	# Add to camera_manager group for discovery
	add_to_group("camera_manager")

	# Create transition camera for camera blending (Phase 10: T181)
	_create_transition_camera()

## Blend cameras between old and new scene (T238)
##
## Captures camera state from old scene (or uses provided state), positions transition camera,
## and smoothly blends to new scene camera over specified duration.
##
## Parameters:
##   old_scene: Scene to capture camera state from (can be null if old_state provided)
##   new_scene: Scene with target camera to blend towards
##   duration: Blend duration in seconds (0 for instant cut)
##   old_state: Optional pre-captured camera state (avoids accessing removed scenes)
##
## Note: Transition camera becomes active during blend, then new camera
## becomes active when blend completes (via _finalize_camera_blend)
func blend_cameras(old_scene: Node, new_scene: Node, duration: float, old_state: CameraState = null) -> void:
	# Use provided state or capture from old scene (T239)
	if old_state == null:
		old_state = capture_camera_state(old_scene)

	if old_state == null:
		push_warning("M_CameraManager: No camera state available for blending")
		return

	# Find new camera in new scene
	var new_camera: Camera3D = _find_camera_in_scene(new_scene)
	if new_camera == null:
		push_warning("M_CameraManager: No camera in new scene for blending")
		return

	# Position transition camera at old state
	_transition_camera.global_position = old_state.global_position
	_transition_camera.global_rotation = old_state.global_rotation
	_transition_camera.fov = old_state.fov

	# Activate transition camera
	_transition_camera.current = true

	# Start blend tween (T240)
	_create_blend_tween(new_camera, duration)

## Capture camera state from scene (T239)
##
## Finds main camera in scene via "main_camera" group and captures
## its global position, rotation, and FOV for blending.
##
## Parameters:
##   scene: Scene to capture camera from
##
## Returns: CameraState or null if no camera found
func capture_camera_state(scene: Node) -> CameraState:
	if scene == null:
		return null

	var camera: Camera3D = _find_camera_in_scene(scene)
	if camera == null:
		return null

	return CameraState.new(
		camera.global_position,
		camera.global_rotation,
		camera.fov
	)

## Initialize scene camera (for external use)
##
## Finds camera in "main_camera" group for potential external access.
## UI scenes may not have cameras, so returns null gracefully.
##
## Parameters:
##   scene: Scene to find camera in
##
## Returns: Camera3D if found, null otherwise
func initialize_scene_camera(scene: Node) -> Camera3D:
	if scene == null:
		return null

	return _find_camera_in_scene(scene)

## Find camera within specific scene subtree
##
## Recursively searches scene's children for a Camera3D node in "main_camera" group.
## Unlike get_tree().get_nodes_in_group(), this searches only within the scene subtree.
##
## Parameters:
##   scene: Root node of scene to search within
##
## Returns: First Camera3D found in "main_camera" group, or null if none found
func _find_camera_in_scene(scene: Node) -> Camera3D:
	if scene == null:
		return null

	# Check if this node is a camera in the main_camera group
	if scene is Camera3D and scene.is_in_group("main_camera"):
		return scene as Camera3D

	# Recursively search children
	for child in scene.get_children():
		var found_camera: Camera3D = _find_camera_in_scene(child)
		if found_camera != null:
			return found_camera

	return null

## Create transition camera for smooth camera blending (T237)
##
## Transition camera is created once in _ready() and reused for all transitions.
## Set to current during blend, then deactivated when blend completes.
func _create_transition_camera() -> void:
	_transition_camera = Camera3D.new()
	_transition_camera.name = "TransitionCamera"
	add_child(_transition_camera)
	_transition_camera.current = false  # Not active by default

## Create blend tween to interpolate camera properties (T240)
##
## Creates tween to animate from current transition camera state to new camera.
## Interpolates position, rotation, and FOV with cubic easing.
##
## Parameters:
##   to_camera: New scene camera to blend towards
##   duration: Blend duration in seconds (0 for instant cut)
func _create_blend_tween(to_camera: Camera3D, duration: float) -> void:
	# Kill existing blend tween if running
	if _camera_blend_tween != null and _camera_blend_tween.is_running():
		_camera_blend_tween.kill()

	# Create tween for blending
	_camera_blend_tween = create_tween()
	_camera_blend_tween.set_parallel(true)  # All properties blend simultaneously
	_camera_blend_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_blend_tween.set_ease(Tween.EASE_IN_OUT)

	# T178: Interpolate position
	_camera_blend_tween.tween_property(_transition_camera, "global_position", to_camera.global_position, duration)

	# T179: Interpolate rotation (quaternion interpolation for smooth results)
	_camera_blend_tween.tween_property(_transition_camera, "global_rotation", to_camera.global_rotation, duration)

	# T180: Interpolate FOV
	_camera_blend_tween.tween_property(_transition_camera, "fov", to_camera.fov, duration)

	# Connect to finished signal to finalize camera switch (T241)
	_camera_blend_tween.finished.connect(_finalize_camera_blend.bind(to_camera), CONNECT_ONE_SHOT)

## Finalize camera blend by activating new scene camera (T241)
##
## Called when blend tween completes. Deactivates transition camera and
## activates the new scene's camera.
##
## Parameters:
##   new_camera: Camera to activate after blend completes
func _finalize_camera_blend(new_camera: Camera3D) -> void:
	if new_camera == null:
		return

	# Deactivate transition camera
	if _transition_camera != null:
		_transition_camera.current = false

	# Activate new scene camera
	new_camera.current = true
