extends BaseTest

## Integration tests for VFX Manager + Camera Manager interaction (Phase 6)
##
## Validates:
## - M_VFXManager applies shake via M_CameraManager
## - Shake affects camera transform via ShakeParent
## - Shake respects enabled toggle and intensity multiplier
## - Trauma decay reduces shake magnitude over time
## - Multiple damage events accumulate trauma (clamped to 1.0)

const M_VFX_MANAGER := preload("res://scripts/managers/m_vfx_manager.gd")
const M_CAMERA_MANAGER := preload("res://scripts/managers/m_camera_manager.gd")
const M_SCREEN_SHAKE := preload("res://scripts/managers/helpers/u_screen_shake.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")

const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/resources/state/rs_navigation_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_VFX_INITIAL_STATE := preload("res://scripts/resources/state/rs_vfx_initial_state.gd")

const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/ecs/u_ecs_event_names.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_HANDOFF := preload("res://scripts/state/utils/u_state_handoff.gd")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_VFX_ACTIONS := preload("res://scripts/state/actions/u_vfx_actions.gd")

var _store: M_StateStore
var _camera_manager: M_CameraManager
var _vfx_manager: M_VFXManager
var _camera_root: Node3D
var _camera: Camera3D


func before_each() -> void:
	U_ECS_EVENT_BUS.reset()
	U_SERVICE_LOCATOR.clear()
	U_STATE_HANDOFF.clear_all()
	await get_tree().process_frame

	_store = M_STATE_STORE.new()
	_store.settings = RS_STATE_STORE_SETTINGS.new()
	_store.settings.enable_persistence = false
	_store.settings.enable_debug_logging = false
	_store.settings.enable_debug_overlay = false
	var gameplay_initial := RS_GAMEPLAY_INITIAL_STATE.new()
	gameplay_initial.player_entity_id = "E_Player"
	_store.gameplay_initial_state = gameplay_initial
	var navigation_initial := RS_NAVIGATION_INITIAL_STATE.new()
	navigation_initial.shell = StringName("gameplay")
	_store.navigation_initial_state = navigation_initial
	_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_store.vfx_initial_state = RS_VFX_INITIAL_STATE.new()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)
	await get_tree().process_frame

	_camera_manager = M_CAMERA_MANAGER.new()
	add_child_autofree(_camera_manager)
	await get_tree().process_frame

	_camera_root = Node3D.new()
	_camera_root.name = "TestCameraRoot"
	add_child_autofree(_camera_root)

	_camera = Camera3D.new()
	_camera.name = "TestMainCamera"
	_camera.current = true
	_camera.position = Vector3(0.0, 1.0, 0.0)
	_camera.rotation = Vector3(0.2, 0.3, 0.0)
	_camera_root.add_child(_camera)
	_camera_manager.register_main_camera(_camera)
	await get_tree().process_frame

	_vfx_manager = M_VFX_MANAGER.new()
	add_child_autofree(_vfx_manager)
	await get_tree().process_frame

	_make_screen_shake_deterministic()


func after_each() -> void:
	U_ECS_EVENT_BUS.reset()
	U_STATE_HANDOFF.clear_all()
	U_SERVICE_LOCATOR.clear()
	super.after_each()


func _make_screen_shake_deterministic() -> void:
	var screen_shake = _vfx_manager.get("_screen_shake")
	if screen_shake == null:
		return

	# Freeze time progression for deterministic sampling.
	screen_shake.noise_speed = 0.0
	# Override random seed for deterministic noise output.
	screen_shake._noise.seed = 1337
	# Default to a non-zero sample time; tests may override.
	screen_shake._time = 10.0


func _get_scene_shake_parent() -> Node3D:
	if _camera == null or not is_instance_valid(_camera):
		return null
	return _camera_manager.get_shake_parent_for_camera(_camera)


func _ensure_shake_parent() -> Node3D:
	_camera_manager.apply_shake_offset(Vector2.ZERO, 0.0)
	return _get_scene_shake_parent()


func _set_shake_sample_time(time_value: float) -> void:
	var screen_shake = _vfx_manager.get("_screen_shake")
	if screen_shake == null:
		return
	screen_shake._time = time_value


func _find_non_zero_sample_time() -> float:
	var candidates: Array[float] = [0.1, 1.0, 10.0, 42.0, 100.0, 777.0]
	for candidate in candidates:
		_set_shake_sample_time(candidate)
		_camera_manager.apply_shake_offset(Vector2.ZERO, 0.0)
		_vfx_manager.set("_trauma", 1.0)
		_store.dispatch(U_VFX_ACTIONS.set_screen_shake_intensity(1.0))
		_vfx_manager._physics_process(0.0)

		var shake_parent := _get_scene_shake_parent()
		if shake_parent == null:
			continue

		var magnitude := shake_parent.position.length()
		var rotation_mag := absf(shake_parent.rotation.z)
		if magnitude > 0.0001 or rotation_mag > 0.0001:
			return candidate

	return -1.0


func test_vfx_applies_shake_to_active_camera() -> void:
	var camera_global_before: Vector3 = _camera.global_position
	var camera_local_rotation_before: Vector3 = _camera.rotation

	_vfx_manager.add_trauma(1.0)
	_vfx_manager._physics_process(0.0)

	var shake_parent := _get_scene_shake_parent()
	assert_not_null(shake_parent, "Camera should be reparented under a ShakeParent node")
	if shake_parent == null:
		return

	var magnitude := shake_parent.position.length()
	var rotation_mag := absf(shake_parent.rotation.z)
	assert_true(magnitude > 0.0001 or rotation_mag > 0.0001,
		"ShakeParent should have non-zero offset or rotation when trauma > 0")

	assert_almost_eq(_camera.rotation, camera_local_rotation_before, Vector3(0.0001, 0.0001, 0.0001),
		"Shake should not mutate the camera's local rotation (parent node isolation)")

	var camera_global_after: Vector3 = _camera.global_position
	assert_true(camera_global_after.distance_to(camera_global_before) > 0.0001,
		"Shake should move the camera in global space via ShakeParent offset")

	assert_almost_eq(shake_parent.rotation.x, 0.0, 0.0001, "ShakeParent should not rotate on X axis")
	assert_almost_eq(shake_parent.rotation.y, 0.0, 0.0001, "ShakeParent should not rotate on Y axis")


func test_screen_shake_disabled_resets_offsets() -> void:
	_vfx_manager.set("_trauma", 1.0)
	_vfx_manager._physics_process(0.0)

	var shake_parent := _get_scene_shake_parent()
	assert_not_null(shake_parent, "ShakeParent should exist after applying shake once")
	if shake_parent == null:
		return

	assert_true(shake_parent.position.length() > 0.0001 or absf(shake_parent.rotation.z) > 0.0001,
		"Sanity check: shake should be non-zero before disabling")

	_store.dispatch(U_VFX_ACTIONS.set_screen_shake_enabled(false))
	_vfx_manager._physics_process(0.0)

	assert_almost_eq(shake_parent.position, Vector3.ZERO, Vector3(0.0001, 0.0001, 0.0001),
		"Disabling screen shake should reset ShakeParent position")
	assert_almost_eq(shake_parent.rotation, Vector3.ZERO, Vector3(0.0001, 0.0001, 0.0001),
		"Disabling screen shake should reset ShakeParent rotation")


func test_screen_shake_intensity_scales_magnitude() -> void:
	var sample_time := _find_non_zero_sample_time()
	assert_true(sample_time > 0.0, "Test requires a non-zero noise sample time")
	if sample_time <= 0.0:
		return

	_set_shake_sample_time(sample_time)
	_vfx_manager.set("_trauma", 1.0)
	_store.dispatch(U_VFX_ACTIONS.set_screen_shake_enabled(true))
	_store.dispatch(U_VFX_ACTIONS.set_screen_shake_intensity(1.0))
	_vfx_manager._physics_process(0.0)

	var shake_parent := _get_scene_shake_parent()
	assert_not_null(shake_parent, "ShakeParent should exist after applying shake")
	if shake_parent == null:
		return

	var magnitude_1x := shake_parent.position.length()
	var rotation_1x := absf(shake_parent.rotation.z)

	_camera_manager.apply_shake_offset(Vector2.ZERO, 0.0)
	_set_shake_sample_time(sample_time)
	_vfx_manager.set("_trauma", 1.0)

	_store.dispatch(U_VFX_ACTIONS.set_screen_shake_intensity(2.0))
	_vfx_manager._physics_process(0.0)

	var magnitude_2x := shake_parent.position.length()
	var rotation_2x := absf(shake_parent.rotation.z)

	assert_almost_eq(magnitude_2x, magnitude_1x * 2.0, 0.001,
		"Intensity 2.0 should double shake position magnitude")
	assert_almost_eq(rotation_2x, rotation_1x * 2.0, 0.001,
		"Intensity 2.0 should double shake rotation magnitude")


func test_trauma_decay_reduces_shake_over_time() -> void:
	var sample_time := _find_non_zero_sample_time()
	assert_true(sample_time > 0.0, "Test requires a non-zero noise sample time")
	if sample_time <= 0.0:
		return

	_set_shake_sample_time(sample_time)
	_store.dispatch(U_VFX_ACTIONS.set_screen_shake_enabled(true))
	_store.dispatch(U_VFX_ACTIONS.set_screen_shake_intensity(1.0))
	_vfx_manager.set("_trauma", 1.0)
	_vfx_manager._physics_process(0.0)

	var shake_parent := _get_scene_shake_parent()
	assert_not_null(shake_parent, "ShakeParent should exist after applying shake")
	if shake_parent == null:
		return

	var magnitude_before := shake_parent.position.length()
	assert_true(magnitude_before > 0.0001, "Sanity check: initial shake magnitude must be non-zero")

	# Decay trauma by 0.5 (TRAUMA_DECAY_RATE=2.0, delta=0.25 => -0.5)
	_set_shake_sample_time(sample_time)
	_vfx_manager._physics_process(0.25)

	assert_almost_eq(_vfx_manager.get_trauma(), 0.5, 0.001, "Trauma should decay to 0.5 after 0.25s")

	var magnitude_after := shake_parent.position.length()
	assert_true(magnitude_after < magnitude_before, "Shake magnitude should decrease as trauma decays")

	# With deterministic noise, shake magnitude should scale with trauma^2.
	assert_almost_eq(magnitude_after, magnitude_before * 0.25, 0.01,
		"Shake magnitude should follow quadratic falloff (0.5^2 = 0.25)")


func test_multiple_damage_events_accumulate_trauma_clamped_to_one() -> void:
	assert_eq(_vfx_manager.get_trauma(), 0.0, "Sanity check: trauma should start at 0")

	# Two max-damage events add trauma twice (0.6 + 0.6), clamped to 1.0.
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SCREEN_SHAKE_REQUEST, {
		"entity_id": "E_Player",
		"trauma_amount": 0.6,
		"source": "damage",
	})
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SCREEN_SHAKE_REQUEST, {
		"entity_id": "E_Player",
		"trauma_amount": 0.6,
		"source": "damage",
	})

	_vfx_manager._physics_process(0.0)

	assert_almost_eq(_vfx_manager.get_trauma(), 1.0, 0.001,
		"Multiple damage events should clamp trauma to 1.0")
	var shake_parent := _get_scene_shake_parent()
	assert_not_null(shake_parent, "ShakeParent should exist after applying shake")
	if shake_parent == null:
		return

	assert_true(shake_parent.position.length() > 0.0001 or absf(shake_parent.rotation.z) > 0.0001,
		"Shake should be applied when trauma is clamped at 1.0")


func test_screen_shake_request_blocked_during_transition() -> void:
	var shake_parent := _ensure_shake_parent()
	assert_not_null(shake_parent, "ShakeParent should exist before gating test")
	if shake_parent == null:
		return

	_store.dispatch(U_SCENE_ACTIONS.transition_started(StringName("test_scene"), "fade"))

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SCREEN_SHAKE_REQUEST, {
		"entity_id": "E_Player",
		"trauma_amount": 0.6,
		"source": "damage",
	})

	_vfx_manager._physics_process(0.0)

	assert_almost_eq(_vfx_manager.get_trauma(), 0.0, 0.0001,
		"Shake requests should be blocked during transitions")
	assert_almost_eq(shake_parent.position, Vector3.ZERO, Vector3(0.0001, 0.0001, 0.0001),
		"ShakeParent should remain at zero offset during transitions")
	assert_almost_eq(shake_parent.rotation, Vector3.ZERO, Vector3(0.0001, 0.0001, 0.0001),
		"ShakeParent should remain at zero rotation during transitions")
