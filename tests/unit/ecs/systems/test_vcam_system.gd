extends BaseTest

const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const S_VCAM_SYSTEM := preload("res://scripts/ecs/systems/s_vcam_system.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const C_CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")
const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const RS_VCAM_MODE_ORBIT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const RS_VCAM_MODE_FIRST_PERSON := preload("res://scripts/resources/display/vcam/rs_vcam_mode_first_person.gd")
const RS_VCAM_MODE_OTS := preload("res://scripts/resources/display/vcam/rs_vcam_mode_ots.gd")
const RS_VCAM_MODE_FIXED := preload("res://scripts/resources/display/vcam/rs_vcam_mode_fixed.gd")
const RS_VCAM_RESPONSE := preload("res://scripts/resources/display/vcam/rs_vcam_response.gd")
const RS_VCAM_SOFT_ZONE := preload("res://scripts/resources/display/vcam/rs_vcam_soft_zone.gd")
const U_VCAM_MODE_EVALUATOR := preload("res://scripts/managers/helpers/u_vcam_mode_evaluator.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/events/ecs/u_ecs_event_names.gd")

class VCamManagerStub extends I_VCamManager:
	var active_vcam_id: StringName = StringName("")
	var previous_vcam_id: StringName = StringName("")
	var blending: bool = false
	var submit_calls: int = 0
	var submissions: Dictionary = {}
	var set_active_calls: Array[Dictionary] = []

	func register_vcam(_vcam: Node) -> void:
		pass

	func unregister_vcam(_vcam: Node) -> void:
		pass

	func set_active_vcam(vcam_id: StringName, blend_duration: float = -1.0) -> void:
		previous_vcam_id = active_vcam_id
		active_vcam_id = vcam_id
		set_active_calls.append({
			"vcam_id": vcam_id,
			"blend_duration": blend_duration,
		})

	func get_active_vcam_id() -> StringName:
		return active_vcam_id

	func get_previous_vcam_id() -> StringName:
		return previous_vcam_id

	func submit_evaluated_camera(vcam_id: StringName, result: Dictionary) -> void:
		submit_calls += 1
		submissions[vcam_id] = result.duplicate(true)

	func get_blend_progress() -> float:
		return 0.0

	func is_blending() -> bool:
		return blending

	func clear_submissions() -> void:
		submit_calls = 0
		submissions.clear()

	func get_submission(vcam_id: StringName) -> Dictionary:
		var submission_variant: Variant = submissions.get(vcam_id, {})
		if submission_variant is Dictionary:
			return (submission_variant as Dictionary).duplicate(true)
		return {}

	func clear_set_active_calls() -> void:
		set_active_calls.clear()

	func get_last_set_active_call() -> Dictionary:
		if set_active_calls.is_empty():
			return {}
		var last_call: Variant = set_active_calls[set_active_calls.size() - 1]
		if last_call is Dictionary:
			return (last_call as Dictionary).duplicate(true)
		return {}

func test_extends_base_ecs_system() -> void:
	var system := S_VCAM_SYSTEM.new()
	autofree(system)
	assert_true(system is BASE_ECS_SYSTEM, "S_VCamSystem should extend BaseECSSystem")

func test_resolves_vcam_manager_via_service_locator() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_TargetA", Vector3(0.0, 0.0, 0.0))
	var orbit_mode := _new_orbit_mode()
	await _create_vcam_component(ecs_manager, StringName("cam_a"), orbit_mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_a")
	ecs_manager._physics_process(0.016)

	assert_eq(vcam_manager.submit_calls, 1, "System should resolve and submit through ServiceLocator vcam manager")

func test_reads_look_input_from_state_and_updates_orbit_rotation() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2(2.0, -1.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_TargetLook", Vector3.ZERO)
	var orbit_mode := _new_orbit_mode(true, 1.5)
	var component := await _create_vcam_component(ecs_manager, StringName("cam_look"), orbit_mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_look")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_yaw, 3.0, 0.0001)
	assert_almost_eq(component.runtime_pitch, -1.5, 0.0001)

func test_evaluates_active_vcam_each_tick() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_TargetEval", Vector3(1.0, 2.0, 3.0))
	var orbit_mode := _new_orbit_mode()
	await _create_vcam_component(ecs_manager, StringName("cam_eval"), orbit_mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_eval")
	ecs_manager._physics_process(0.016)

	var result: Dictionary = vcam_manager.get_submission(StringName("cam_eval"))
	assert_true(result.has("transform"), "Active vcam should be evaluated into a transform result")
	assert_eq(String(result.get("mode_name", "")), "orbit", "Result should come from orbit evaluator branch")

func test_updates_runtime_rotation_for_orbit_when_enabled() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2(1.0, 2.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_TargetOrbitEnabled", Vector3.ZERO)
	var orbit_mode := _new_orbit_mode(true, 2.0)
	var component := await _create_vcam_component(ecs_manager, StringName("cam_orbit_enabled"), orbit_mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_orbit_enabled")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_yaw, 2.0, 0.0001)
	assert_almost_eq(component.runtime_pitch, 4.0, 0.0001)

func test_orbit_lock_x_rotation_prevents_runtime_yaw_updates() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2(2.0, -3.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_TargetOrbitLockX", Vector3.ZERO)
	var orbit_mode := _new_orbit_mode(true, 1.5)
	orbit_mode.lock_x_rotation = true
	orbit_mode.lock_y_rotation = false
	var component := await _create_vcam_component(ecs_manager, StringName("cam_orbit_lock_x"), orbit_mode, follow_target)

	component.runtime_yaw = 9.0
	component.runtime_pitch = 1.0
	vcam_manager.active_vcam_id = StringName("cam_orbit_lock_x")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_yaw, 0.0, 0.0001)
	assert_almost_eq(component.runtime_pitch, -3.5, 0.0001)

func test_orbit_lock_y_rotation_prevents_runtime_pitch_updates() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2(1.5, 4.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_TargetOrbitLockY", Vector3.ZERO)
	var orbit_mode := _new_orbit_mode(true, 2.0)
	orbit_mode.lock_x_rotation = false
	orbit_mode.lock_y_rotation = true
	var component := await _create_vcam_component(ecs_manager, StringName("cam_orbit_lock_y"), orbit_mode, follow_target)

	component.runtime_yaw = -2.0
	component.runtime_pitch = 6.0
	vcam_manager.active_vcam_id = StringName("cam_orbit_lock_y")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_yaw, 1.0, 0.0001)
	assert_almost_eq(component.runtime_pitch, 0.0, 0.0001)

func test_does_not_update_orbit_rotation_when_player_rotation_disabled() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2(3.0, -4.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_TargetOrbitDisabled", Vector3.ZERO)
	var orbit_mode := _new_orbit_mode(false, 3.0)
	var component := await _create_vcam_component(ecs_manager, StringName("cam_orbit_disabled"), orbit_mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_orbit_disabled")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_yaw, 0.0, 0.0001)
	assert_almost_eq(component.runtime_pitch, 0.0, 0.0001)

func test_updates_first_person_rotation_using_look_multiplier() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2(1.0, -0.5)})
	var follow_target := _create_target_entity(ecs_manager, "E_TargetFP", Vector3.ZERO)
	var first_person_mode := _new_first_person_mode(2.0)
	var component := await _create_vcam_component(ecs_manager, StringName("cam_fp"), first_person_mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_fp")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_yaw, 2.0, 0.0001)
	assert_almost_eq(component.runtime_pitch, -1.0, 0.0001)

func test_updates_ots_rotation_using_look_multiplier_with_non_inverted_pitch_and_non_inverted_horizontal() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2(1.0, 0.5)})
	var follow_target := _create_target_entity(ecs_manager, "E_TargetOTS", Vector3.ZERO)
	var ots_mode := _new_ots_mode(2.0)
	var component := await _create_vcam_component(ecs_manager, StringName("cam_ots"), ots_mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_yaw, -2.0, 0.0001)
	assert_almost_eq(component.runtime_pitch, -1.0, 0.0001)

func test_updates_ots_rotation_with_negative_horizontal_input_rotates_positive_runtime_yaw() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2(-1.0, 0.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_TargetOTSHorizontal", Vector3.ZERO)
	var ots_mode := _new_ots_mode(2.0)
	var component := await _create_vcam_component(ecs_manager, StringName("cam_ots_horizontal"), ots_mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_horizontal")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_yaw, 2.0, 0.0001)

func test_ots_runtime_pitch_clamps_to_lower_bound_during_input_accumulation() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2(0.0, 40.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_TargetOTSClampLow", Vector3.ZERO)
	var ots_mode := _new_ots_mode(2.0)
	ots_mode.pitch_min = -30.0
	ots_mode.pitch_max = 20.0
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ots_clamp_low"),
		ots_mode,
		follow_target
	)

	vcam_manager.active_vcam_id = StringName("cam_ots_clamp_low")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_pitch, -30.0, 0.0001)

func test_ots_runtime_pitch_clamps_to_upper_bound_during_input_accumulation() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2(0.0, -40.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_TargetOTSClampHigh", Vector3.ZERO)
	var ots_mode := _new_ots_mode(2.0)
	ots_mode.pitch_min = -30.0
	ots_mode.pitch_max = 20.0
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ots_clamp_high"),
		ots_mode,
		follow_target
	)

	vcam_manager.active_vcam_id = StringName("cam_ots_clamp_high")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_pitch, 20.0, 0.0001)

func test_aim_pressed_switches_active_vcam_from_orbit_to_first_person_with_aim_blend_duration() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_AimSwitchTarget", Vector3.ZERO)
	await _create_vcam_component(ecs_manager, StringName("cam_orbit_aim"), _new_orbit_mode(), follow_target)
	var first_person_mode := _new_first_person_mode(1.0)
	first_person_mode.aim_blend_duration = 0.22
	await _create_vcam_component(ecs_manager, StringName("cam_first_person_aim"), first_person_mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_orbit_aim")
	vcam_manager.clear_set_active_calls()
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "aim_pressed": true, "camera_center_just_pressed": false})
	ecs_manager._physics_process(0.016)

	assert_eq(vcam_manager.active_vcam_id, StringName("cam_first_person_aim"))
	var set_active_call: Dictionary = vcam_manager.get_last_set_active_call()
	assert_eq(set_active_call.get("vcam_id", StringName("")), StringName("cam_first_person_aim"))
	assert_almost_eq(float(set_active_call.get("blend_duration", 0.0)), 0.22, 0.0001)

func test_aim_release_restores_previous_vcam_with_first_person_aim_exit_blend_duration() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_AimRestoreTarget", Vector3.ZERO)
	await _create_vcam_component(ecs_manager, StringName("cam_orbit_restore"), _new_orbit_mode(), follow_target)
	var first_person_mode := _new_first_person_mode(1.0)
	first_person_mode.aim_blend_duration = 0.18
	first_person_mode.aim_exit_blend_duration = 0.27
	await _create_vcam_component(ecs_manager, StringName("cam_first_person_restore"), first_person_mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_orbit_restore")
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "aim_pressed": true, "camera_center_just_pressed": false})
	ecs_manager._physics_process(0.016)
	assert_eq(vcam_manager.active_vcam_id, StringName("cam_first_person_restore"))

	vcam_manager.clear_set_active_calls()
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "aim_pressed": false, "camera_center_just_pressed": false})
	ecs_manager._physics_process(0.016)

	assert_eq(vcam_manager.active_vcam_id, StringName("cam_orbit_restore"))
	var set_active_call: Dictionary = vcam_manager.get_last_set_active_call()
	assert_eq(set_active_call.get("vcam_id", StringName("")), StringName("cam_orbit_restore"))
	assert_almost_eq(float(set_active_call.get("blend_duration", 0.0)), 0.27, 0.0001)

func test_aim_activation_noops_when_no_first_person_target_exists() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_AimNoFPTarget", Vector3.ZERO)
	await _create_vcam_component(ecs_manager, StringName("cam_orbit_only"), _new_orbit_mode(), follow_target)

	vcam_manager.active_vcam_id = StringName("cam_orbit_only")
	vcam_manager.clear_set_active_calls()
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "aim_pressed": true, "camera_center_just_pressed": false})
	ecs_manager._physics_process(0.016)

	assert_eq(vcam_manager.active_vcam_id, StringName("cam_orbit_only"))
	assert_true(vcam_manager.set_active_calls.is_empty())

func test_aim_activation_prefers_first_person_vcam_with_matching_follow_target() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var target_a := _create_target_entity(ecs_manager, "E_AimTargetA", Vector3.ZERO)
	var target_b := _create_target_entity(ecs_manager, "E_AimTargetB", Vector3(2.0, 0.0, 0.0))
	await _create_vcam_component(ecs_manager, StringName("cam_orbit_match"), _new_orbit_mode(), target_a)
	await _create_vcam_component(ecs_manager, StringName("cam_fp_other"), _new_first_person_mode(), target_b)
	await _create_vcam_component(ecs_manager, StringName("cam_fp_match"), _new_first_person_mode(), target_a)

	vcam_manager.active_vcam_id = StringName("cam_orbit_match")
	vcam_manager.clear_set_active_calls()
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "aim_pressed": true, "camera_center_just_pressed": false})
	ecs_manager._physics_process(0.016)

	assert_eq(vcam_manager.active_vcam_id, StringName("cam_fp_match"))

func test_aim_blend_duration_clamps_to_minimum_when_authored_non_positive() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_AimBlendClampTarget", Vector3.ZERO)
	await _create_vcam_component(ecs_manager, StringName("cam_orbit_clamp"), _new_orbit_mode(), follow_target)
	var first_person_mode := _new_first_person_mode()
	first_person_mode.aim_blend_duration = 0.0
	await _create_vcam_component(ecs_manager, StringName("cam_fp_clamp"), first_person_mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_orbit_clamp")
	vcam_manager.clear_set_active_calls()
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "aim_pressed": true, "camera_center_just_pressed": false})
	ecs_manager._physics_process(0.016)

	var set_active_call: Dictionary = vcam_manager.get_last_set_active_call()
	assert_almost_eq(float(set_active_call.get("blend_duration", -1.0)), 0.01, 0.0001)

func test_first_person_strafe_tilt_is_disabled_when_angle_is_zero() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(1.0, 0.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_FPStrafeDisabled", Vector3.ZERO)
	var mode := _new_first_person_mode(1.0)
	mode.strafe_tilt_angle = 0.0
	mode.strafe_tilt_smoothing = 6.0
	await _create_vcam_component(ecs_manager, StringName("cam_fp_strafe_disabled"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_fp_strafe_disabled")
	for _i in range(30):
		ecs_manager._physics_process(0.016)

	var transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_fp_strafe_disabled"))
	assert_almost_eq(_extract_roll_degrees(transform), 0.0, 0.001)

func test_first_person_strafe_tilt_rolls_negative_when_strafing_left() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(-1.0, 0.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_FPStrafeLeft", Vector3.ZERO)
	var mode := _new_first_person_mode(1.0)
	mode.strafe_tilt_angle = 10.0
	mode.strafe_tilt_smoothing = 8.0
	await _create_vcam_component(ecs_manager, StringName("cam_fp_strafe_left"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_fp_strafe_left")
	for _i in range(120):
		ecs_manager._physics_process(0.016)

	var transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_fp_strafe_left"))
	assert_true(_extract_roll_degrees(transform) < -0.5)

func test_first_person_strafe_tilt_rolls_positive_when_strafing_right() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(1.0, 0.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_FPStrafeRight", Vector3.ZERO)
	var mode := _new_first_person_mode(1.0)
	mode.strafe_tilt_angle = 10.0
	mode.strafe_tilt_smoothing = 8.0
	await _create_vcam_component(ecs_manager, StringName("cam_fp_strafe_right"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_fp_strafe_right")
	for _i in range(120):
		ecs_manager._physics_process(0.016)

	var transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_fp_strafe_right"))
	assert_true(_extract_roll_degrees(transform) > 0.5)

func test_first_person_strafe_tilt_scales_with_lateral_input_strength() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(0.25, 0.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_FPStrafeScale", Vector3.ZERO)
	var mode := _new_first_person_mode(1.0)
	mode.strafe_tilt_angle = 12.0
	mode.strafe_tilt_smoothing = 10.0
	await _create_vcam_component(ecs_manager, StringName("cam_fp_strafe_scale"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_fp_strafe_scale")
	for _i in range(120):
		ecs_manager._physics_process(0.016)
	var partial_roll: float = absf(
		_extract_roll_degrees(_extract_submission_transform(vcam_manager, StringName("cam_fp_strafe_scale")))
	)

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(1.0, 0.0)})
	for _j in range(120):
		ecs_manager._physics_process(0.016)
	var full_roll: float = absf(
		_extract_roll_degrees(_extract_submission_transform(vcam_manager, StringName("cam_fp_strafe_scale")))
	)

	assert_true(full_roll > (partial_roll + 0.5))
	assert_true(full_roll <= 12.25)

func test_first_person_strafe_tilt_does_not_exceed_authored_max_angle() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(1.0, 0.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_FPStrafeMax", Vector3.ZERO)
	var mode := _new_first_person_mode(1.0)
	mode.strafe_tilt_angle = 8.0
	mode.strafe_tilt_smoothing = 12.0
	await _create_vcam_component(ecs_manager, StringName("cam_fp_strafe_max"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_fp_strafe_max")
	for _i in range(180):
		ecs_manager._physics_process(0.016)

	var roll: float = absf(
		_extract_roll_degrees(_extract_submission_transform(vcam_manager, StringName("cam_fp_strafe_max")))
	)
	assert_true(roll <= 8.1)

func test_first_person_strafe_tilt_returns_to_zero_when_lateral_input_stops() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(1.0, 0.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_FPStrafeReturn", Vector3.ZERO)
	var mode := _new_first_person_mode(1.0)
	mode.strafe_tilt_angle = 10.0
	mode.strafe_tilt_smoothing = 6.0
	await _create_vcam_component(ecs_manager, StringName("cam_fp_strafe_return"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_fp_strafe_return")
	for _i in range(120):
		ecs_manager._physics_process(0.016)
	var active_roll: float = absf(
		_extract_roll_degrees(_extract_submission_transform(vcam_manager, StringName("cam_fp_strafe_return")))
	)
	assert_true(active_roll > 0.5)

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2.ZERO})
	for _j in range(150):
		ecs_manager._physics_process(0.016)
	var settled_roll: float = absf(
		_extract_roll_degrees(_extract_submission_transform(vcam_manager, StringName("cam_fp_strafe_return")))
	)
	assert_true(settled_roll < active_roll)
	assert_true(settled_roll < 0.1)

func test_first_person_strafe_tilt_is_noop_for_orbit_and_fixed_modes() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(1.0, 0.0)})
	var orbit_target := _create_target_entity(ecs_manager, "E_StrafeNoopOrbit", Vector3.ZERO)
	var orbit_mode := _new_orbit_mode(false, 0.0)
	var orbit_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_strafe_noop_orbit"),
		orbit_mode,
		orbit_target
	)

	vcam_manager.active_vcam_id = StringName("cam_strafe_noop_orbit")
	ecs_manager._physics_process(0.016)

	var orbit_submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_strafe_noop_orbit"))
	var orbit_raw_result: Dictionary = _evaluate_raw_result(orbit_mode, orbit_target, orbit_component)
	var orbit_raw_transform := orbit_raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	_assert_transform_close(orbit_submitted, orbit_raw_transform, 0.0001, 0.0001)

	var fixed_target := _create_target_entity(ecs_manager, "E_StrafeNoopFixed", Vector3(2.0, 0.0, 0.0))
	var fixed_mode := RS_VCAM_MODE_FIXED.new()
	fixed_mode.use_world_anchor = true
	fixed_mode.track_target = false
	var fixed_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_strafe_noop_fixed"),
		fixed_mode,
		fixed_target
	)

	vcam_manager.active_vcam_id = StringName("cam_strafe_noop_fixed")
	ecs_manager._physics_process(0.016)

	var fixed_submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_strafe_noop_fixed"))
	var fixed_raw_result: Dictionary = _evaluate_raw_result(fixed_mode, fixed_target, fixed_component)
	var fixed_raw_transform := fixed_raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	_assert_transform_close(fixed_submitted, fixed_raw_transform, 0.0001, 0.0001)

func test_ots_shoulder_sway_is_disabled_when_angle_is_zero() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(1.0, 0.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_OTSShoulderSwayDisabled", Vector3.ZERO)
	var mode := _new_ots_mode(1.0)
	mode.shoulder_sway_angle = 0.0
	mode.shoulder_sway_smoothing = 6.0
	await _create_vcam_component(ecs_manager, StringName("cam_ots_shoulder_sway_disabled"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_shoulder_sway_disabled")
	for _i in range(30):
		ecs_manager._physics_process(0.016)

	var transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ots_shoulder_sway_disabled"))
	assert_almost_eq(_extract_roll_degrees(transform), 0.0, 0.001)

func test_ots_shoulder_sway_rolls_negative_when_strafing_left() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(-1.0, 0.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_OTSShoulderSwayLeft", Vector3.ZERO)
	var mode := _new_ots_mode(1.0)
	mode.shoulder_sway_angle = 10.0
	mode.shoulder_sway_smoothing = 8.0
	await _create_vcam_component(ecs_manager, StringName("cam_ots_shoulder_sway_left"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_shoulder_sway_left")
	for _i in range(120):
		ecs_manager._physics_process(0.016)

	var transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ots_shoulder_sway_left"))
	assert_true(_extract_roll_degrees(transform) < -0.5)

func test_ots_shoulder_sway_rolls_positive_when_strafing_right() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(1.0, 0.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_OTSShoulderSwayRight", Vector3.ZERO)
	var mode := _new_ots_mode(1.0)
	mode.shoulder_sway_angle = 10.0
	mode.shoulder_sway_smoothing = 8.0
	await _create_vcam_component(ecs_manager, StringName("cam_ots_shoulder_sway_right"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_shoulder_sway_right")
	for _i in range(120):
		ecs_manager._physics_process(0.016)

	var transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ots_shoulder_sway_right"))
	assert_true(_extract_roll_degrees(transform) > 0.5)

func test_ots_shoulder_sway_scales_with_lateral_input_strength() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(0.25, 0.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_OTSShoulderSwayScale", Vector3.ZERO)
	var mode := _new_ots_mode(1.0)
	mode.shoulder_sway_angle = 12.0
	mode.shoulder_sway_smoothing = 10.0
	await _create_vcam_component(ecs_manager, StringName("cam_ots_shoulder_sway_scale"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_shoulder_sway_scale")
	for _i in range(120):
		ecs_manager._physics_process(0.016)
	var partial_roll: float = absf(
		_extract_roll_degrees(_extract_submission_transform(vcam_manager, StringName("cam_ots_shoulder_sway_scale")))
	)

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(1.0, 0.0)})
	for _j in range(120):
		ecs_manager._physics_process(0.016)
	var full_roll: float = absf(
		_extract_roll_degrees(_extract_submission_transform(vcam_manager, StringName("cam_ots_shoulder_sway_scale")))
	)

	assert_true(full_roll > (partial_roll + 0.5))
	assert_true(full_roll <= 12.25)

func test_ots_shoulder_sway_does_not_exceed_authored_max_angle() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(1.0, 0.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_OTSShoulderSwayMax", Vector3.ZERO)
	var mode := _new_ots_mode(1.0)
	mode.shoulder_sway_angle = 8.0
	mode.shoulder_sway_smoothing = 12.0
	await _create_vcam_component(ecs_manager, StringName("cam_ots_shoulder_sway_max"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_shoulder_sway_max")
	for _i in range(180):
		ecs_manager._physics_process(0.016)

	var roll: float = absf(
		_extract_roll_degrees(_extract_submission_transform(vcam_manager, StringName("cam_ots_shoulder_sway_max")))
	)
	assert_true(roll <= 8.1)

func test_ots_shoulder_sway_returns_to_zero_when_lateral_input_stops() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(1.0, 0.0)})
	var follow_target := _create_target_entity(ecs_manager, "E_OTSShoulderSwayReturn", Vector3.ZERO)
	var mode := _new_ots_mode(1.0)
	mode.shoulder_sway_angle = 10.0
	mode.shoulder_sway_smoothing = 6.0
	await _create_vcam_component(ecs_manager, StringName("cam_ots_shoulder_sway_return"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_shoulder_sway_return")
	for _i in range(120):
		ecs_manager._physics_process(0.016)
	var active_roll: float = absf(
		_extract_roll_degrees(_extract_submission_transform(vcam_manager, StringName("cam_ots_shoulder_sway_return")))
	)
	assert_true(active_roll > 0.5)

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2.ZERO})
	for _j in range(150):
		ecs_manager._physics_process(0.016)
	var settled_roll: float = absf(
		_extract_roll_degrees(_extract_submission_transform(vcam_manager, StringName("cam_ots_shoulder_sway_return")))
	)
	assert_true(settled_roll < active_roll)
	assert_true(settled_roll < 0.1)

func test_ots_shoulder_sway_is_noop_for_orbit_and_fixed_modes() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "move_input": Vector2(1.0, 0.0)})
	var orbit_target := _create_target_entity(ecs_manager, "E_OTSShoulderSwayNoopOrbit", Vector3.ZERO)
	var orbit_mode := _new_orbit_mode(false, 0.0)
	var orbit_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ots_shoulder_sway_noop_orbit"),
		orbit_mode,
		orbit_target
	)

	vcam_manager.active_vcam_id = StringName("cam_ots_shoulder_sway_noop_orbit")
	ecs_manager._physics_process(0.016)

	var orbit_submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ots_shoulder_sway_noop_orbit"))
	var orbit_raw_result: Dictionary = _evaluate_raw_result(orbit_mode, orbit_target, orbit_component)
	var orbit_raw_transform := orbit_raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	_assert_transform_close(orbit_submitted, orbit_raw_transform, 0.0001, 0.0001)

	var fixed_target := _create_target_entity(ecs_manager, "E_OTSShoulderSwayNoopFixed", Vector3.ZERO)
	var fixed_mode := RS_VCAM_MODE_FIXED.new()
	fixed_mode.use_world_anchor = false
	fixed_mode.follow_offset = Vector3(0.0, 0.0, 4.0)
	fixed_mode.track_target = false
	var fixed_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ots_shoulder_sway_noop_fixed"),
		fixed_mode,
		fixed_target
	)

	vcam_manager.active_vcam_id = StringName("cam_ots_shoulder_sway_noop_fixed")
	ecs_manager._physics_process(0.016)

	var fixed_submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ots_shoulder_sway_noop_fixed"))
	var fixed_raw_result: Dictionary = _evaluate_raw_result(fixed_mode, fixed_target, fixed_component)
	var fixed_raw_transform := fixed_raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	_assert_transform_close(fixed_submitted, fixed_raw_transform, 0.0001, 0.0001)

func test_ots_collision_avoidance_keeps_full_distance_when_unobstructed() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_OTSNoCollisionTarget", Vector3.ZERO)
	var mode := _new_ots_mode()
	mode.shoulder_offset = Vector3.ZERO
	mode.camera_distance = 4.0
	mode.collision_probe_radius = 0.2
	var component := await _create_vcam_component(ecs_manager, StringName("cam_ots_no_collision"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_no_collision")
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ots_no_collision"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_almost_eq(submitted.origin.distance_to(follow_target.global_position), 4.0, 0.02)
	_assert_transform_close(submitted, raw_transform, 0.0001, 0.0001)

func test_ots_collision_avoidance_uses_shoulder_pivot_for_initial_overlap_guard() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var floor_obstacle := _create_box_obstacle("OTSFloorGuard", Vector3(0.0, -0.3, 0.0), Vector3(12.0, 0.6, 12.0))
	await _pump()
	await _pump()

	var follow_target := _create_target_entity(ecs_manager, "E_OTSShoulderPivotTarget", Vector3.ZERO)
	var mode := _new_ots_mode()
	mode.shoulder_offset = Vector3(0.3, 1.6, -0.5)
	mode.camera_distance = 2.0
	mode.collision_probe_radius = 0.2
	var component := await _create_vcam_component(ecs_manager, StringName("cam_ots_floor_guard"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_floor_guard")
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ots_floor_guard"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var expected_pivot: Vector3 = follow_target.global_position + (Vector3.UP * mode.shoulder_offset.y)
	var expected_distance: float = raw_transform.origin.distance_to(expected_pivot)
	var submitted_distance: float = submitted.origin.distance_to(expected_pivot)

	assert_almost_eq(submitted_distance, expected_distance, 0.05)
	assert_true(
		submitted_distance > 1.4,
		"Floor overlap at follow-target origin should not collapse OTS distance when shoulder pivot is elevated"
	)
	assert_not_null(floor_obstacle)

func test_ots_collision_avoidance_clamps_distance_when_obstructed() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var obstacle := _create_box_obstacle("OTSWall", Vector3(0.0, 0.0, 2.0), Vector3(2.0, 2.0, 0.2))
	await _pump()
	await _pump()

	var follow_target := _create_target_entity(ecs_manager, "E_OTSCollisionTarget", Vector3.ZERO)
	var mode := _new_ots_mode()
	mode.shoulder_offset = Vector3.ZERO
	mode.camera_distance = 4.0
	mode.collision_probe_radius = 0.15
	await _create_vcam_component(ecs_manager, StringName("cam_ots_collision"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_collision")
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ots_collision"))
	var distance_to_target: float = submitted.origin.distance_to(follow_target.global_position)
	assert_true(distance_to_target < 3.0, "Collision should clamp distance when wall is behind target")
	assert_true(distance_to_target >= 0.099, "Clamped distance should stay above the minimum floor")
	assert_not_null(obstacle)

func test_ots_collision_avoidance_probe_radius_affects_off_axis_obstacles() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	_create_box_obstacle("OTSOffAxis", Vector3(0.30, 0.0, 2.0), Vector3(0.10, 2.0, 0.2))
	await _pump()
	await _pump()

	var follow_target := _create_target_entity(ecs_manager, "E_OTSProbeRadiusTarget", Vector3.ZERO)
	var small_probe_mode := _new_ots_mode()
	small_probe_mode.shoulder_offset = Vector3.ZERO
	small_probe_mode.camera_distance = 4.0
	small_probe_mode.collision_probe_radius = 0.05
	var large_probe_mode := _new_ots_mode()
	large_probe_mode.shoulder_offset = Vector3.ZERO
	large_probe_mode.camera_distance = 4.0
	large_probe_mode.collision_probe_radius = 0.40
	await _create_vcam_component(ecs_manager, StringName("cam_ots_probe_small"), small_probe_mode, follow_target)
	await _create_vcam_component(ecs_manager, StringName("cam_ots_probe_large"), large_probe_mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_probe_small")
	ecs_manager._physics_process(0.016)
	var small_probe_distance: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ots_probe_small")
	).origin.distance_to(follow_target.global_position)

	vcam_manager.active_vcam_id = StringName("cam_ots_probe_large")
	ecs_manager._physics_process(0.016)
	var large_probe_distance: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ots_probe_large")
	).origin.distance_to(follow_target.global_position)

	assert_true(small_probe_distance > 3.8, "Small probe should miss this off-axis blocker")
	assert_true(
		large_probe_distance < (small_probe_distance - 0.6),
		"Larger probe radius should detect off-axis blocker and clamp camera distance"
	)

func test_ots_collision_avoidance_applies_minimum_distance_floor() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	_create_box_obstacle("OTSVeryNearWall", Vector3(0.0, 0.0, 0.04), Vector3(2.0, 2.0, 0.08))
	await _pump()
	await _pump()

	var follow_target := _create_target_entity(ecs_manager, "E_OTSMinFloorTarget", Vector3.ZERO)
	var mode := _new_ots_mode()
	mode.shoulder_offset = Vector3.ZERO
	mode.camera_distance = 1.0
	mode.collision_probe_radius = 0.25
	await _create_vcam_component(ecs_manager, StringName("cam_ots_min_floor"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_min_floor")
	ecs_manager._physics_process(0.016)

	var distance_to_target: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ots_min_floor")
	).origin.distance_to(follow_target.global_position)
	assert_true(distance_to_target >= 0.099, "Collision clamp should honor minimum distance floor")
	assert_true(
		distance_to_target < 0.50,
		"Camera should still pull close when obstruction is extremely near (distance=%.3f)" % [distance_to_target]
	)

func test_ots_collision_avoidance_recovers_smoothly_after_obstruction_clears() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var obstacle := _create_box_obstacle("OTSRecoverWall", Vector3(0.0, 0.0, 2.0), Vector3(2.0, 2.0, 0.2))
	await _pump()
	await _pump()

	var follow_target := _create_target_entity(ecs_manager, "E_OTSRecoverTarget", Vector3.ZERO)
	var mode := _new_ots_mode()
	mode.shoulder_offset = Vector3.ZERO
	mode.camera_distance = 4.0
	mode.collision_probe_radius = 0.15
	mode.collision_recovery_speed = 2.0
	await _create_vcam_component(ecs_manager, StringName("cam_ots_recover"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_recover")
	ecs_manager._physics_process(0.016)
	var blocked_distance: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ots_recover")
	).origin.distance_to(follow_target.global_position)

	obstacle.queue_free()
	await _pump()
	await _pump()

	ecs_manager._physics_process(0.016)
	var first_recovery_distance: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ots_recover")
	).origin.distance_to(follow_target.global_position)
	for _i in range(120):
		ecs_manager._physics_process(0.016)
	var settled_distance: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ots_recover")
	).origin.distance_to(follow_target.global_position)

	assert_true(first_recovery_distance > blocked_distance, "Distance should start recovering once obstruction clears")
	assert_true(first_recovery_distance < 3.9, "Recovery should be smooth, not an instant full snap-out")
	assert_true(settled_distance > first_recovery_distance, "Recovery should continue over subsequent ticks")
	assert_almost_eq(settled_distance, 4.0, 0.05)

func test_ots_collision_avoidance_is_noop_for_orbit_and_fixed_modes() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	_create_box_obstacle("OTSNoopModesWall", Vector3(0.0, 0.0, 2.0), Vector3(4.0, 6.0, 0.2))
	await _pump()
	await _pump()

	var orbit_target := _create_target_entity(ecs_manager, "E_OTSNoopOrbitTarget", Vector3.ZERO)
	var orbit_mode := _new_orbit_mode(false, 0.0)
	var orbit_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ots_noop_orbit"),
		orbit_mode,
		orbit_target
	)
	vcam_manager.active_vcam_id = StringName("cam_ots_noop_orbit")
	ecs_manager._physics_process(0.016)
	var orbit_submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ots_noop_orbit"))
	var orbit_raw := _evaluate_raw_result(orbit_mode, orbit_target, orbit_component).get(
		"transform",
		Transform3D.IDENTITY
	) as Transform3D
	_assert_transform_close(orbit_submitted, orbit_raw, 0.0001, 0.0001)

	var fixed_target := _create_target_entity(ecs_manager, "E_OTSNoopFixedTarget", Vector3.ZERO)
	var fixed_mode := RS_VCAM_MODE_FIXED.new()
	fixed_mode.use_world_anchor = false
	fixed_mode.follow_offset = Vector3(0.0, 0.0, 4.0)
	fixed_mode.track_target = false
	var fixed_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ots_noop_fixed"),
		fixed_mode,
		fixed_target
	)
	vcam_manager.active_vcam_id = StringName("cam_ots_noop_fixed")
	ecs_manager._physics_process(0.016)
	var fixed_submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ots_noop_fixed"))
	var fixed_raw := _evaluate_raw_result(fixed_mode, fixed_target, fixed_component).get(
		"transform",
		Transform3D.IDENTITY
	) as Transform3D
	_assert_transform_close(fixed_submitted, fixed_raw, 0.0001, 0.0001)

func test_runtime_rotation_values_remain_raw_targets_with_response_enabled() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	store.set_slice(StringName("input"), {"look_input": Vector2(1.5, -0.75)})
	var follow_target := _create_target_entity(ecs_manager, "E_RawRuntimeResponseTarget", Vector3.ZERO)
	var orbit_mode := _new_orbit_mode(true, 2.0)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_raw_runtime_response"),
		orbit_mode,
		follow_target
	)
	component.response = _new_response(3.0, 0.7, 1.0, 1.25, 0.85, 1.0)

	vcam_manager.active_vcam_id = StringName("cam_raw_runtime_response")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_yaw, 3.0, 0.0001)
	assert_almost_eq(component.runtime_pitch, -1.5, 0.0001)

func test_submits_evaluated_result_to_manager() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_TargetSubmit", Vector3.ZERO)
	var orbit_mode := _new_orbit_mode()
	await _create_vcam_component(ecs_manager, StringName("cam_submit"), orbit_mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_submit")
	ecs_manager._physics_process(0.016)

	assert_eq(vcam_manager.submit_calls, 1, "Active vcam should submit exactly one evaluated result")
	assert_true(vcam_manager.submissions.has(StringName("cam_submit")), "Submission should be keyed by vcam_id")

func test_evaluates_outgoing_vcam_when_blending() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target_a := _create_target_entity(ecs_manager, "E_TargetBlendA", Vector3(0.0, 0.0, 0.0))
	var follow_target_b := _create_target_entity(ecs_manager, "E_TargetBlendB", Vector3(5.0, 0.0, 0.0))
	await _create_vcam_component(ecs_manager, StringName("cam_a"), _new_orbit_mode(), follow_target_a)
	await _create_vcam_component(ecs_manager, StringName("cam_b"), _new_orbit_mode(), follow_target_b)

	vcam_manager.active_vcam_id = StringName("cam_b")
	vcam_manager.previous_vcam_id = StringName("cam_a")
	vcam_manager.blending = true
	ecs_manager._physics_process(0.016)

	assert_eq(vcam_manager.submit_calls, 2, "Blend tick should evaluate active and outgoing vcams")
	assert_true(vcam_manager.submissions.has(StringName("cam_a")))
	assert_true(vcam_manager.submissions.has(StringName("cam_b")))

func test_resolves_follow_target_from_node_path_before_entity_fallback() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var path_target := _create_target_entity(ecs_manager, "E_PathTarget", Vector3(1.0, 2.0, 3.0), StringName("path_target"))
	var fallback_target := _create_target_entity(ecs_manager, "E_FallbackTarget", Vector3(20.0, 0.0, 0.0), StringName("fallback_target"))
	ecs_manager.register_entity(path_target)
	ecs_manager.register_entity(fallback_target)

	var component := await _create_vcam_component(ecs_manager, StringName("cam_path_priority"), _new_orbit_mode(), path_target)
	component.follow_target_entity_id = StringName("fallback_target")

	vcam_manager.active_vcam_id = StringName("cam_path_priority")
	ecs_manager._physics_process(0.016)

	var result: Dictionary = vcam_manager.get_submission(StringName("cam_path_priority"))
	var transform := result.get("transform", Transform3D.IDENTITY) as Transform3D
	var expected_position: Vector3 = _expected_orbit_position(path_target.global_position)
	assert_almost_eq(transform.origin.x, expected_position.x, 0.001)
	assert_almost_eq(transform.origin.y, expected_position.y, 0.001)
	assert_almost_eq(transform.origin.z, expected_position.z, 0.001)

func test_falls_back_to_entity_id_when_follow_target_path_is_empty() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var fallback_target := _create_target_entity(
		ecs_manager,
		"E_EntityTarget",
		Vector3(4.0, 0.0, -2.0),
		StringName("entity_target")
	)
	ecs_manager.register_entity(fallback_target)

	var component := await _create_vcam_component(ecs_manager, StringName("cam_entity_fallback"), _new_orbit_mode())
	component.follow_target_entity_id = StringName("entity_target")

	vcam_manager.active_vcam_id = StringName("cam_entity_fallback")
	ecs_manager._physics_process(0.016)

	var result: Dictionary = vcam_manager.get_submission(StringName("cam_entity_fallback"))
	var transform := result.get("transform", Transform3D.IDENTITY) as Transform3D
	var expected_position: Vector3 = _expected_orbit_position(fallback_target.global_position)
	assert_almost_eq(transform.origin.x, expected_position.x, 0.001)
	assert_almost_eq(transform.origin.y, expected_position.y, 0.001)
	assert_almost_eq(transform.origin.z, expected_position.z, 0.001)

func test_falls_back_to_tag_when_node_path_and_entity_id_are_missing() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var tagged_target := _create_target_entity(
		ecs_manager,
		"E_TagTarget",
		Vector3(2.0, 1.0, 0.0),
		StringName("tag_target"),
		[StringName("player")]
	)
	ecs_manager.register_entity(tagged_target)

	var component := await _create_vcam_component(ecs_manager, StringName("cam_tag_fallback"), _new_orbit_mode())
	component.follow_target_tag = StringName("player")

	vcam_manager.active_vcam_id = StringName("cam_tag_fallback")
	ecs_manager._physics_process(0.016)

	var result: Dictionary = vcam_manager.get_submission(StringName("cam_tag_fallback"))
	var transform := result.get("transform", Transform3D.IDENTITY) as Transform3D
	var expected_position: Vector3 = _expected_orbit_position(tagged_target.global_position)
	assert_almost_eq(transform.origin.x, expected_position.x, 0.001)
	assert_almost_eq(transform.origin.y, expected_position.y, 0.001)
	assert_almost_eq(transform.origin.z, expected_position.z, 0.001)

func test_multiple_tag_matches_use_first_entity_and_record_debug_issue() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var first_target := _create_target_entity(
		ecs_manager,
		"E_FirstTagTarget",
		Vector3(0.0, 0.0, 0.0),
		StringName("first_tag_target"),
		[StringName("player")]
	)
	var second_target := _create_target_entity(
		ecs_manager,
		"E_SecondTagTarget",
		Vector3(10.0, 0.0, 0.0),
		StringName("second_tag_target"),
		[StringName("player")]
	)
	ecs_manager.register_entity(first_target)
	ecs_manager.register_entity(second_target)

	var component := await _create_vcam_component(ecs_manager, StringName("cam_multi_tag"), _new_orbit_mode())
	component.follow_target_tag = StringName("player")

	vcam_manager.active_vcam_id = StringName("cam_multi_tag")
	ecs_manager._physics_process(0.016)

	var result: Dictionary = vcam_manager.get_submission(StringName("cam_multi_tag"))
	var transform := result.get("transform", Transform3D.IDENTITY) as Transform3D
	var expected_position: Vector3 = _expected_orbit_position(first_target.global_position)
	assert_almost_eq(transform.origin.x, expected_position.x, 0.001)
	assert_almost_eq(transform.origin.y, expected_position.y, 0.001)
	assert_almost_eq(transform.origin.z, expected_position.z, 0.001)

	var debug_issues: Array[String] = system.get_debug_issues()
	assert_true(debug_issues.size() > 0, "Multiple tag matches should record a debug issue")
	assert_true(debug_issues[debug_issues.size() - 1].contains("multiple entities"))

func test_use_path_helper_is_created_under_gameplay_path_node() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_PathFollowTarget", Vector3(0.0, 0.0, 2.0))
	var path_host := _create_target_entity(ecs_manager, "E_PathHost", Vector3.ZERO)
	var path_node := _create_path_node(path_host, "PathTrack")

	var fixed_mode := _new_fixed_path_mode()
	var component := await _create_vcam_component(ecs_manager, StringName("cam_path"), fixed_mode, follow_target)
	component.path_node_path = path_node.get_path()

	vcam_manager.active_vcam_id = StringName("cam_path")
	ecs_manager._physics_process(0.016)

	var path_helpers: Dictionary = (context["system"] as S_VCamSystem).get("_path_follow_helpers") as Dictionary
	var helper := path_helpers.get(StringName("cam_path"), null) as PathFollow3D
	assert_not_null(helper, "Path mode should create a PathFollow3D helper")
	assert_eq(helper.get_parent(), path_node, "Path helper should live under gameplay Path3D node")
	assert_false(vcam_manager.is_ancestor_of(helper), "Helper must not be parented under persistent manager nodes")

func test_use_path_with_invalid_follow_target_preserves_progress_and_skips_submit() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_PathInvalidTarget", Vector3(0.0, 0.0, 2.0))
	var path_host := _create_target_entity(ecs_manager, "E_PathInvalidHost", Vector3.ZERO)
	var path_node := _create_path_node(path_host, "PathTrackInvalid")

	var fixed_mode := _new_fixed_path_mode()
	var component := await _create_vcam_component(ecs_manager, StringName("cam_path_invalid"), fixed_mode, follow_target)
	component.path_node_path = path_node.get_path()

	vcam_manager.active_vcam_id = StringName("cam_path_invalid")
	ecs_manager._physics_process(0.016)

	var path_helpers: Dictionary = system.get("_path_follow_helpers") as Dictionary
	var helper := path_helpers.get(StringName("cam_path_invalid"), null) as PathFollow3D
	assert_not_null(helper)
	var progress_before: float = helper.progress

	component.follow_target_path = NodePath("")
	component.follow_target_entity_id = StringName("")
	component.follow_target_tag = StringName("")
	vcam_manager.clear_submissions()

	ecs_manager._physics_process(0.016)

	assert_eq(vcam_manager.submit_calls, 0, "Invalid path target should enter recovery and skip submission")
	assert_almost_eq(helper.progress, progress_before, 0.0001, "Path progress should not advance without a valid follow target")

func test_active_follow_target_loss_holds_last_submission_and_requests_reselection() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_RecoveryFollowTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_recovery_target_loss"),
		_new_orbit_mode(),
		follow_target
	)

	vcam_manager.active_vcam_id = StringName("cam_recovery_target_loss")
	vcam_manager.clear_set_active_calls()
	ecs_manager._physics_process(0.016)

	var initial_result: Dictionary = vcam_manager.get_submission(StringName("cam_recovery_target_loss"))
	assert_false(initial_result.is_empty(), "Expected an initial valid submission before recovery")
	var initial_transform := initial_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var initial_submit_calls: int = vcam_manager.submit_calls
	var history_start: int = U_ECS_EVENT_BUS.get_event_history().size()

	component.follow_target_path = NodePath("")
	component.follow_target_entity_id = StringName("")
	component.follow_target_tag = StringName("")
	ecs_manager._physics_process(0.016)

	assert_eq(
		vcam_manager.submit_calls,
		initial_submit_calls,
		"Target loss should skip new submission and keep the last valid pose active"
	)
	var held_result: Dictionary = vcam_manager.get_submission(StringName("cam_recovery_target_loss"))
	var held_transform := held_result.get("transform", Transform3D.IDENTITY) as Transform3D
	_assert_transform_close(held_transform, initial_transform, 0.0001, 0.0001)

	var reselection_call: Dictionary = vcam_manager.get_last_set_active_call()
	assert_eq(
		reselection_call.get("vcam_id", StringName("missing")),
		StringName(""),
		"Invalid active target should request manager reselection"
	)

	var recovery_payload: Dictionary = {}
	var history: Array = U_ECS_EVENT_BUS.get_event_history()
	for index in range(history_start, history.size()):
		var event_variant: Variant = history[index]
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant as Dictionary
		if event.get("name", StringName("")) != U_ECS_EVENT_NAMES.EVENT_VCAM_RECOVERY:
			continue
		var payload_variant: Variant = event.get("payload", {})
		if payload_variant is Dictionary:
			recovery_payload = (payload_variant as Dictionary).duplicate(true)
			break
	assert_false(recovery_payload.is_empty(), "Target-loss recovery should publish EVENT_VCAM_RECOVERY")
	assert_eq(String(recovery_payload.get("reason", "")), "target_freed")
	assert_eq(
		recovery_payload.get("vcam_id", StringName("")),
		StringName("cam_recovery_target_loss")
	)

func test_fixed_world_anchor_missing_falls_back_to_entity_root() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var fixed_mode := RS_VCAM_MODE_FIXED.new()
	fixed_mode.use_world_anchor = true
	fixed_mode.use_path = false
	fixed_mode.track_target = false
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_fixed_anchor_fallback"),
		fixed_mode
	)
	component.fixed_anchor_path = NodePath("MissingAnchor")
	var host_entity := component.get_parent() as Node3D
	assert_not_null(host_entity, "Expected vCam host entity root for fallback resolution")
	host_entity.global_position = Vector3(4.0, 1.5, -2.0)

	vcam_manager.active_vcam_id = StringName("cam_fixed_anchor_fallback")
	vcam_manager.clear_set_active_calls()
	ecs_manager._physics_process(0.016)

	var result: Dictionary = vcam_manager.get_submission(StringName("cam_fixed_anchor_fallback"))
	assert_false(result.is_empty(), "Fixed world-anchor fallback should still evaluate and submit")
	var submitted := result.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_almost_eq(submitted.origin.x, host_entity.global_position.x, 0.001)
	assert_almost_eq(submitted.origin.y, host_entity.global_position.y, 0.001)
	assert_almost_eq(submitted.origin.z, host_entity.global_position.z, 0.001)
	assert_true(
		vcam_manager.set_active_calls.is_empty(),
		"Entity-root anchor fallback should avoid triggering recovery reselection"
	)

func test_look_smoothing_offsets_first_frame_after_large_look_input_jump() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_LookSmoothingJumpTarget", Vector3.ZERO)
	var mode := _new_first_person_mode(1.0)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_smoothing_jump"),
		mode,
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 1.0, 1.0, 1.0)

	vcam_manager.active_vcam_id = StringName("cam_look_smoothing_jump")
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2(45.0, 0.0)})
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_yaw, 45.0, 0.0001)
	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_look_smoothing_jump"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_true(
		_rotation_error(submitted, raw_transform) > 0.001,
		"First frame after look jump should be smoothed, not raw target rotation"
	)

func test_look_smoothing_converges_toward_raw_rotation_over_ticks() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_LookSmoothingConvergeTarget", Vector3.ZERO)
	var mode := _new_first_person_mode(1.0)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_smoothing_converge"),
		mode,
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 1.0, 1.0, 1.0)

	vcam_manager.active_vcam_id = StringName("cam_look_smoothing_converge")
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2(60.0, 0.0)})
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var first_transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_look_smoothing_converge"))
	var first_error: float = _rotation_error(first_transform, raw_transform)
	for _i in range(180):
		ecs_manager._physics_process(0.016)

	var final_transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_look_smoothing_converge"))
	var final_error: float = _rotation_error(final_transform, raw_transform)

	assert_true(first_error > 0.001, "Look smoothing should introduce non-zero first-frame rotation error")
	assert_true(final_error < first_error, "Look smoothing should converge toward raw evaluator rotation")
	assert_true(final_error < 0.01, "Look smoothing should settle close to raw evaluator rotation")

func test_mode_switch_resets_look_smoothing_without_residual_momentum() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_LookSmoothingModeResetTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_smoothing_mode_reset"),
		_new_first_person_mode(1.0),
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 1.0, 1.0, 1.0)

	vcam_manager.active_vcam_id = StringName("cam_look_smoothing_mode_reset")
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2(55.0, 0.0)})
	ecs_manager._physics_process(0.016)
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	for _i in range(6):
		ecs_manager._physics_process(0.016)

	component.mode = _new_orbit_mode()
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_look_smoothing_mode_reset"))
	var raw_result: Dictionary = _evaluate_raw_result(component.mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	_assert_transform_close(submitted, raw_transform, 0.0001, 0.0001)

func test_follow_target_change_resets_look_smoothing_state() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var first_target := _create_target_entity(ecs_manager, "E_LookSmoothingTargetA", Vector3.ZERO)
	var second_target := _create_target_entity(ecs_manager, "E_LookSmoothingTargetB", Vector3(5.0, 0.0, 0.0))
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_smoothing_target_reset"),
		_new_first_person_mode(1.0),
		first_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 1.0, 1.0, 1.0)

	vcam_manager.active_vcam_id = StringName("cam_look_smoothing_target_reset")
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2(40.0, 0.0)})
	ecs_manager._physics_process(0.016)
	var pre_state: Dictionary = (system.get("_look_rotation_state") as Dictionary).get(
		StringName("cam_look_smoothing_target_reset"),
		{}
	) as Dictionary
	assert_true(absf(float(pre_state.get("yaw_velocity", 0.0))) > 0.0001)

	component.follow_target_path = second_target.get_path()
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	ecs_manager._physics_process(0.016)

	var post_state: Dictionary = (system.get("_look_rotation_state") as Dictionary).get(
		StringName("cam_look_smoothing_target_reset"),
		{}
	) as Dictionary
	assert_eq(int(post_state.get("follow_target_id", 0)), second_target.get_instance_id())
	assert_almost_eq(float(post_state.get("yaw_velocity", 1.0)), 0.0, 0.0001)
	assert_almost_eq(float(post_state.get("pitch_velocity", 1.0)), 0.0, 0.0001)
	assert_almost_eq(float(post_state.get("smoothed_yaw", -999.0)), component.runtime_yaw, 0.0001)
	assert_almost_eq(float(post_state.get("smoothed_pitch", -999.0)), component.runtime_pitch, 0.0001)

func test_response_change_resets_look_smoothing_state() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_LookSmoothingResponseTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_smoothing_response_reset"),
		_new_first_person_mode(1.0),
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 1.0, 1.0, 1.0)

	vcam_manager.active_vcam_id = StringName("cam_look_smoothing_response_reset")
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2(35.0, 0.0)})
	ecs_manager._physics_process(0.016)
	var pre_state: Dictionary = (system.get("_look_rotation_state") as Dictionary).get(
		StringName("cam_look_smoothing_response_reset"),
		{}
	) as Dictionary
	assert_true(absf(float(pre_state.get("yaw_velocity", 0.0))) > 0.0001)

	var response := component.response as RS_VCAM_RESPONSE
	response.rotation_frequency = 2.5
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	ecs_manager._physics_process(0.016)

	var post_state: Dictionary = (system.get("_look_rotation_state") as Dictionary).get(
		StringName("cam_look_smoothing_response_reset"),
		{}
	) as Dictionary
	assert_ne(pre_state.get("response_signature", []), post_state.get("response_signature", []))
	assert_almost_eq(float(post_state.get("yaw_velocity", 1.0)), 0.0, 0.0001)
	assert_almost_eq(float(post_state.get("pitch_velocity", 1.0)), 0.0, 0.0001)
	assert_almost_eq(float(post_state.get("smoothed_yaw", -999.0)), component.runtime_yaw, 0.0001)
	assert_almost_eq(float(post_state.get("smoothed_pitch", -999.0)), component.runtime_pitch, 0.0001)

func test_orbit_release_smoothing_preserves_velocity_then_decelerates() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_OrbitReleaseDampingTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_release_damping"),
		_new_orbit_mode(true, 1.0),
		follow_target
	)
	component.response = _new_response()
	component.response.look_input_hold_sec = 0.0
	component.response.look_input_release_decay = 10000.0
	component.response.look_release_yaw_damping = 8.0
	component.response.look_release_pitch_damping = 8.0
	component.response.look_release_stop_threshold = 0.0

	vcam_manager.active_vcam_id = StringName("cam_orbit_release_damping")
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2(6.0, 3.0)})
	ecs_manager._physics_process(0.016)
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	ecs_manager._physics_process(0.016)
	var release_state := (system.get("_look_rotation_state") as Dictionary).get(
		StringName("cam_orbit_release_damping"),
		{}
	) as Dictionary
	var first_release_velocity_yaw: float = absf(float(release_state.get("yaw_velocity", 0.0)))
	var first_release_velocity_pitch: float = absf(float(release_state.get("pitch_velocity", 0.0)))
	assert_true(first_release_velocity_yaw > 0.0001, "Release tick should keep non-zero yaw velocity")
	assert_true(first_release_velocity_pitch > 0.0001, "Release tick should keep non-zero pitch velocity")

	ecs_manager._physics_process(0.016)
	var post_release_state := (system.get("_look_rotation_state") as Dictionary).get(
		StringName("cam_orbit_release_damping"),
		{}
	) as Dictionary
	var second_release_velocity_yaw: float = absf(float(post_release_state.get("yaw_velocity", 0.0)))
	var second_release_velocity_pitch: float = absf(float(post_release_state.get("pitch_velocity", 0.0)))
	assert_true(
		second_release_velocity_yaw < first_release_velocity_yaw,
		"Yaw release velocity should decelerate after input release"
	)
	assert_true(
		second_release_velocity_pitch < first_release_velocity_pitch,
		"Pitch release velocity should decelerate after input release"
	)

func test_orbit_release_smoothing_supports_asymmetric_axis_damping() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_OrbitReleaseAsymTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_release_asymmetric"),
		_new_orbit_mode(true, 1.0),
		follow_target
	)
	component.response = _new_response()
	component.response.look_input_hold_sec = 0.0
	component.response.look_input_release_decay = 10000.0
	component.response.look_release_yaw_damping = 1.0
	component.response.look_release_pitch_damping = 30.0
	component.response.look_release_stop_threshold = 0.0

	vcam_manager.active_vcam_id = StringName("cam_orbit_release_asymmetric")
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2(8.0, 8.0)})
	ecs_manager._physics_process(0.016)
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	ecs_manager._physics_process(0.016)
	var release_state := (system.get("_look_rotation_state") as Dictionary).get(
		StringName("cam_orbit_release_asymmetric"),
		{}
	) as Dictionary
	var yaw_velocity_abs: float = absf(float(release_state.get("yaw_velocity", 0.0)))
	var pitch_velocity_abs: float = absf(float(release_state.get("pitch_velocity", 0.0)))
	assert_true(yaw_velocity_abs > 0.0001, "Asymmetric test requires non-zero yaw velocity on release")
	assert_true(
		yaw_velocity_abs > (pitch_velocity_abs * 1.5),
		"Lower yaw damping should retain more release velocity than higher pitch damping"
	)

func test_orbit_release_smoothing_stop_threshold_clamps_velocity_and_prevents_drift() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_OrbitReleaseThresholdTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_release_threshold"),
		_new_orbit_mode(true, 1.0),
		follow_target
	)
	component.response = _new_response()
	component.response.look_input_hold_sec = 0.0
	component.response.look_input_release_decay = 10000.0
	component.response.look_release_yaw_damping = 18.0
	component.response.look_release_pitch_damping = 18.0
	component.response.look_release_stop_threshold = 0.05

	vcam_manager.active_vcam_id = StringName("cam_orbit_release_threshold")
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2(6.0, 4.0)})
	ecs_manager._physics_process(0.016)
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	for _i in range(180):
		ecs_manager._physics_process(0.016)

	var settled_state := (system.get("_look_rotation_state") as Dictionary).get(
		StringName("cam_orbit_release_threshold"),
		{}
	) as Dictionary
	assert_almost_eq(float(settled_state.get("yaw_velocity", 1.0)), 0.0, 0.0001)
	assert_almost_eq(float(settled_state.get("pitch_velocity", 1.0)), 0.0, 0.0001)
	var settled_yaw: float = float(settled_state.get("smoothed_yaw", 0.0))
	var settled_pitch: float = float(settled_state.get("smoothed_pitch", 0.0))

	for _j in range(60):
		ecs_manager._physics_process(0.016)
	var post_state := (system.get("_look_rotation_state") as Dictionary).get(
		StringName("cam_orbit_release_threshold"),
		{}
	) as Dictionary
	assert_almost_eq(float(post_state.get("smoothed_yaw", 1.0)), settled_yaw, 0.0001)
	assert_almost_eq(float(post_state.get("smoothed_pitch", 1.0)), settled_pitch, 0.0001)

func test_orbit_release_axis_settles_when_near_target_crossing_would_flip_error() -> void:
	var system := S_VCAM_SYSTEM.new()
	autofree(system)
	system.debug_rotation_logging = false

	var result_variant: Variant = system.call(
		"_step_orbit_release_axis",
		StringName("cam_orbit_release_axis_settle"),
		"yaw",
		-0.1,
		0.0,
		60.0,
		4.8,
		0.9,
		10.0,
		0.05,
		0.0167
	)
	assert_true(result_variant is Dictionary)
	var result := result_variant as Dictionary
	assert_almost_eq(float(result.get("value", 1.0)), 0.0, 0.0001)
	assert_almost_eq(float(result.get("velocity", 1.0)), 0.0, 0.0001)

func test_orbit_release_smoothing_is_gated_to_orbit_mode() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_ReleaseModeGateTarget", Vector3.ZERO)
	var first_person_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_release_mode_gate_fp"),
		_new_first_person_mode(1.0),
		follow_target
	)
	first_person_component.response = _new_response()
	first_person_component.response.look_input_hold_sec = 0.0
	first_person_component.response.look_input_release_decay = 10000.0
	first_person_component.response.look_release_yaw_damping = 0.5
	first_person_component.response.look_release_pitch_damping = 0.5
	first_person_component.response.look_release_stop_threshold = 0.0

	vcam_manager.active_vcam_id = StringName("cam_release_mode_gate_fp")
	ecs_manager._physics_process(0.016)
	store.set_slice(StringName("input"), {"look_input": Vector2(5.0, 5.0)})
	ecs_manager._physics_process(0.016)
	ecs_manager._physics_process(0.016)
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	ecs_manager._physics_process(0.016)

	var fp_state := (system.get("_look_rotation_state") as Dictionary).get(
		StringName("cam_release_mode_gate_fp"),
		{}
	) as Dictionary
	assert_almost_eq(
		float(fp_state.get("yaw_velocity", 1.0)),
		0.0,
		0.0001,
		"First-person release behavior should remain unchanged by orbit-only release damping"
	)
	assert_almost_eq(float(fp_state.get("pitch_velocity", 1.0)), 0.0, 0.0001)

	var fixed_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_release_mode_gate_fixed"),
		_new_fixed_path_mode(),
		follow_target
	)
	fixed_component.response = _new_response()
	vcam_manager.active_vcam_id = StringName("cam_release_mode_gate_fixed")
	store.set_slice(StringName("input"), {"look_input": Vector2(5.0, 5.0)})
	ecs_manager._physics_process(0.016)
	var look_state_all: Dictionary = system.get("_look_rotation_state") as Dictionary
	assert_false(
		look_state_all.has(StringName("cam_release_mode_gate_fixed")),
		"Fixed mode should not use look smoothing/release state"
	)

func test_camera_center_button_starts_orbit_recentering_from_arbitrary_yaw() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_CenterStartTarget", Vector3.ZERO)
	follow_target.rotation_degrees.y = 90.0
	var orbit_mode := _new_orbit_mode(true, 1.0)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_center_start"),
		orbit_mode,
		follow_target
	)
	component.runtime_yaw = -120.0

	var expected_target: float = float(
		system.call("_resolve_orbit_center_target_yaw", orbit_mode, follow_target, component.runtime_yaw)
	)
	vcam_manager.active_vcam_id = StringName("cam_center_start")
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "camera_center_just_pressed": true})
	ecs_manager._physics_process(0.016)

	var center_state := (system.get("_orbit_centering_state") as Dictionary).get(
		StringName("cam_center_start"),
		{}
	) as Dictionary
	assert_false(center_state.is_empty(), "camera_center should create per-vCam centering state")
	var initial_error: float = absf(wrapf(expected_target - (-120.0), -180.0, 180.0))
	var current_error: float = absf(wrapf(expected_target - component.runtime_yaw, -180.0, 180.0))
	assert_true(current_error < initial_error, "First centering tick should reduce yaw error toward target")
	assert_true(current_error > 0.1, "Centering should not snap to target on first frame")

func test_camera_center_recenters_over_short_interpolation_window_without_snap() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_CenterWindowTarget", Vector3.ZERO)
	var orbit_mode := _new_orbit_mode(true, 1.0)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_center_window"),
		orbit_mode,
		follow_target
	)
	component.runtime_yaw = -170.0

	var expected_target: float = float(
		system.call("_resolve_orbit_center_target_yaw", orbit_mode, follow_target, component.runtime_yaw)
	)
	vcam_manager.active_vcam_id = StringName("cam_center_window")
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "camera_center_just_pressed": true})
	ecs_manager._physics_process(0.016)

	var error_after_first_tick: float = absf(wrapf(expected_target - component.runtime_yaw, -180.0, 180.0))
	assert_true(error_after_first_tick > 0.1, "Recentering should start with interpolation, not an instant cut")

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "aim_pressed": false, "camera_center_just_pressed": false})
	for _i in range(20):
		ecs_manager._physics_process(0.016)

	var final_error: float = absf(wrapf(expected_target - component.runtime_yaw, -180.0, 180.0))
	assert_true(final_error <= 0.05, "Recentering should complete near 0.3s")
	var center_state_all: Dictionary = system.get("_orbit_centering_state") as Dictionary
	assert_false(center_state_all.has(StringName("cam_center_window")), "Centering state should clear after completion")

func test_camera_center_ignores_manual_look_input_while_centering_active() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_CenterInputGateTarget", Vector3.ZERO)
	var orbit_mode := _new_orbit_mode(true, 1.5)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_center_input_gate"),
		orbit_mode,
		follow_target
	)
	component.runtime_yaw = 145.0

	var expected_target: float = float(
		system.call("_resolve_orbit_center_target_yaw", orbit_mode, follow_target, component.runtime_yaw)
	)
	vcam_manager.active_vcam_id = StringName("cam_center_input_gate")
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "camera_center_just_pressed": true})
	ecs_manager._physics_process(0.016)
	var yaw_after_start: float = component.runtime_yaw
	var error_after_start: float = absf(wrapf(expected_target - yaw_after_start, -180.0, 180.0))

	store.set_slice(StringName("input"), {"look_input": Vector2(400.0, 0.0), "camera_center_just_pressed": false})
	ecs_manager._physics_process(0.016)
	var error_after_manual_input: float = absf(wrapf(expected_target - component.runtime_yaw, -180.0, 180.0))
	assert_true(
		error_after_manual_input <= error_after_start,
		"Manual look input should not pull orbit yaw away while centering is active"
	)
	assert_true(
		(system.get("_orbit_centering_state") as Dictionary).has(StringName("cam_center_input_gate")),
		"Centering should remain active while interpolating"
	)

func test_camera_center_retrigger_restarts_from_current_pose_deterministically() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_CenterRestartTarget", Vector3.ZERO)
	var orbit_mode := _new_orbit_mode(true, 1.0)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_center_restart"),
		orbit_mode,
		follow_target
	)
	component.runtime_yaw = -135.0

	vcam_manager.active_vcam_id = StringName("cam_center_restart")
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "camera_center_just_pressed": true})
	ecs_manager._physics_process(0.016)
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "camera_center_just_pressed": false})
	for _i in range(4):
		ecs_manager._physics_process(0.016)

	var yaw_before_restart: float = component.runtime_yaw
	follow_target.rotation_degrees.y = 135.0
	var restart_target: float = float(
		system.call("_resolve_orbit_center_target_yaw", orbit_mode, follow_target, yaw_before_restart)
	)

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "camera_center_just_pressed": true})
	ecs_manager._physics_process(0.016)

	var center_state := (system.get("_orbit_centering_state") as Dictionary).get(
		StringName("cam_center_restart"),
		{}
	) as Dictionary
	assert_false(center_state.is_empty())
	assert_almost_eq(float(center_state.get("start_yaw", 9999.0)), yaw_before_restart, 0.001)
	assert_almost_eq(float(center_state.get("target_yaw", 9999.0)), restart_target, 0.001)
	assert_true(float(center_state.get("elapsed_sec", 1.0)) <= 0.02)

func test_response_smoothing_offsets_first_frame_after_target_moves() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_SmoothTarget", Vector3.ZERO)
	var mode := _new_first_person_mode()
	var component := await _create_vcam_component(ecs_manager, StringName("cam_response_active"), mode, follow_target)
	component.response = _new_response()

	vcam_manager.active_vcam_id = StringName("cam_response_active")
	ecs_manager._physics_process(0.016)

	follow_target.global_position = Vector3(12.0, 0.0, 0.0)
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_response_active"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_true(
		submitted.origin.distance_to(raw_transform.origin) > 0.001,
		"First frame after target movement should use smoothed position, not raw evaluator output"
	)

func test_orbit_rotation_input_does_not_add_follow_position_lag_when_target_stationary() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_OrbitStationaryTarget", Vector3.ZERO)
	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_stationary_rotation"),
		mode,
		follow_target
	)
	component.response = _new_response(1.0, 0.7, 1.0, 4.0, 1.0, 1.0)

	vcam_manager.active_vcam_id = StringName("cam_orbit_stationary_rotation")
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2(2.0, 0.0)})
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_orbit_stationary_rotation"))
	var look_state_all: Dictionary = system.get("_look_rotation_state") as Dictionary
	var look_state := look_state_all.get(StringName("cam_orbit_stationary_rotation"), {}) as Dictionary
	assert_false(look_state.is_empty(), "Orbit look smoothing state should exist after look input")

	var smoothed_yaw: float = float(look_state.get("smoothed_yaw", component.runtime_yaw))
	var smoothed_pitch: float = float(look_state.get("smoothed_pitch", component.runtime_pitch))
	var expected_result: Dictionary = U_VCAM_MODE_EVALUATOR.evaluate(
		mode,
		follow_target,
		component.get_look_at_target(),
		smoothed_yaw,
		smoothed_pitch
	)
	var expected_transform := expected_result.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(
		submitted.origin.distance_to(expected_transform.origin),
		0.0,
		0.0001,
		"Orbit rotation input should not add extra follow-position lag when follow target is stationary"
	)

func test_look_filter_hold_keeps_first_person_input_active_without_extra_runtime_rotation() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_FPHoldTarget", Vector3.ZERO)
	var mode := _new_first_person_mode(1.0)
	var component := await _create_vcam_component(ecs_manager, StringName("cam_fp_hold"), mode, follow_target)
	component.response = _new_response(
		3.0,
		0.7,
		1.0,
		4.0,
		1.0,
		1.0,
		0.0,
		3.0,
		0.0,
		1.0,
		0.01,
		0.08,
		100.0
	)

	vcam_manager.active_vcam_id = StringName("cam_fp_hold")
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2(12.0, 0.0)})
	ecs_manager._physics_process(0.016)
	assert_almost_eq(component.runtime_yaw, 12.0, 0.0001)

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	ecs_manager._physics_process(0.016)
	assert_almost_eq(
		component.runtime_yaw,
		12.0,
		0.0001,
		"Hold/decay filtering should not add extra runtime yaw when raw input is zero"
	)
	var look_state_all: Dictionary = system.get("_look_rotation_state") as Dictionary
	var look_state := look_state_all.get(StringName("cam_fp_hold"), {}) as Dictionary
	assert_true(bool(look_state.get("input_active", false)), "Hold window should keep look input active")

func test_look_filter_hold_keeps_orbit_input_active_without_extra_runtime_rotation() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_OrbitHoldTarget", Vector3.ZERO)
	var mode := _new_orbit_mode(true, 1.0)
	var component := await _create_vcam_component(ecs_manager, StringName("cam_orbit_hold"), mode, follow_target)
	component.response = _new_response(
		3.0,
		0.7,
		1.0,
		4.0,
		1.0,
		1.0,
		0.0,
		3.0,
		0.0,
		1.0,
		0.01,
		0.08,
		100.0
	)

	vcam_manager.active_vcam_id = StringName("cam_orbit_hold")
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2(8.0, 0.0)})
	ecs_manager._physics_process(0.016)
	assert_almost_eq(component.runtime_yaw, 8.0, 0.0001)

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	ecs_manager._physics_process(0.016)
	assert_almost_eq(
		component.runtime_yaw,
		8.0,
		0.0001,
		"Hold/decay filtering should not add extra runtime yaw when raw orbit input is zero"
	)
	var look_state_all: Dictionary = system.get("_look_rotation_state") as Dictionary
	var look_state := look_state_all.get(StringName("cam_orbit_hold"), {}) as Dictionary
	assert_true(bool(look_state.get("input_active", false)), "Hold window should keep orbit look input active")

func test_look_filter_release_decay_deactivates_input_after_hold_window() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_FPDecayTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_fp_decay"),
		_new_first_person_mode(1.0),
		follow_target
	)
	component.response = _new_response(
		3.0,
		0.7,
		1.0,
		4.0,
		1.0,
		1.0,
		0.0,
		3.0,
		0.0,
		1.0,
		0.01,
		0.02,
		100.0
	)

	vcam_manager.active_vcam_id = StringName("cam_fp_decay")
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2(10.0, 0.0)})
	ecs_manager._physics_process(0.016)
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	for _i in range(8):
		ecs_manager._physics_process(0.02)

	var look_state_all: Dictionary = system.get("_look_rotation_state") as Dictionary
	var look_state := look_state_all.get(StringName("cam_fp_decay"), {}) as Dictionary
	assert_false(bool(look_state.get("input_active", true)), "Release decay should eventually clear active look state")

func test_look_filter_large_spike_release_decay_clears_activity_promptly() -> void:
	var system := S_VCAM_SYSTEM.new()
	autofree(system)
	system.debug_rotation_logging = false

	var response_values := {
		"look_input_deadzone": 0.02,
		"look_input_hold_sec": 0.06,
		"look_input_release_decay": 25.0,
	}
	var vcam_id := StringName("cam_look_filter_spike")

	var first_filtered_variant: Variant = system.call(
		"_resolve_filtered_look_input",
		vcam_id,
		Vector2(-217.0, 194.0),
		response_values,
		0.016
	)
	assert_true(first_filtered_variant is Vector2)
	var first_filtered := first_filtered_variant as Vector2
	assert_true(first_filtered.length() > 200.0)

	for _i in range(48):
		system.call(
			"_resolve_filtered_look_input",
			vcam_id,
			Vector2.ZERO,
			response_values,
			0.016
		)

	var filter_state_all: Dictionary = system.get("_look_input_filter_state") as Dictionary
	var filter_state := filter_state_all.get(vcam_id, {}) as Dictionary
	assert_false(
		bool(filter_state.get("input_active", true)),
		"Large one-frame look spikes should decay to inactive within a short release window"
	)
	var filtered_input := filter_state.get("filtered_input", Vector2.ONE) as Vector2
	assert_true(
		filtered_input.length() < 0.02,
		"Filtered look magnitude should settle near zero after the decay window"
	)

func test_orbit_moving_target_disables_position_smoothing_bypass_during_look_input() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_OrbitMovingBypassTarget", Vector3.ZERO)
	var mode := _new_orbit_mode(true, 1.0)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_moving_bypass"),
		mode,
		follow_target
	)
	component.response = _new_response(
		1.0,
		0.7,
		1.0,
		4.0,
		1.0,
		1.0,
		0.0,
		3.0,
		0.0,
		1.0,
		0.01,
		0.0,
		25.0,
		0.15,
		0.3
	)

	vcam_manager.active_vcam_id = StringName("cam_orbit_moving_bypass")
	ecs_manager._physics_process(0.016)

	follow_target.global_position = Vector3(1.0, 0.0, 0.0)
	store.set_slice(StringName("input"), {"look_input": Vector2(2.0, 0.0)})
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	var bypass_state_all: Dictionary = system.get("_debug_position_smoothing_bypass_by_vcam") as Dictionary
	assert_false(
		bool(bypass_state_all.get(StringName("cam_orbit_moving_bypass"), true)),
		"Moving follow target should disable orbit position smoothing bypass"
	)
	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_orbit_moving_bypass"))
	var look_state_all: Dictionary = system.get("_look_rotation_state") as Dictionary
	var look_state := look_state_all.get(StringName("cam_orbit_moving_bypass"), {}) as Dictionary
	var smoothed_yaw: float = float(look_state.get("smoothed_yaw", component.runtime_yaw))
	var smoothed_pitch: float = float(look_state.get("smoothed_pitch", component.runtime_pitch))
	var expected_result: Dictionary = U_VCAM_MODE_EVALUATOR.evaluate(
		mode,
		follow_target,
		component.get_look_at_target(),
		smoothed_yaw,
		smoothed_pitch
	)
	var expected_transform := expected_result.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_true(
		submitted.origin.distance_to(expected_transform.origin) > 0.001,
		"Moving target should keep follow-position smoothing active while rotating"
	)

func test_orbit_position_smoothing_bypass_hysteresis_uses_enable_and_disable_speeds() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_OrbitBypassHysteresisTarget", Vector3.ZERO)
	var mode := _new_orbit_mode(true, 1.0)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_bypass_hysteresis"),
		mode,
		follow_target
	)
	component.response = _new_response(
		1.0,
		0.7,
		1.0,
		4.0,
		1.0,
		1.0,
		0.0,
		3.0,
		0.0,
		1.0,
		0.01,
		0.0,
		25.0,
		0.15,
		0.3
	)

	vcam_manager.active_vcam_id = StringName("cam_orbit_bypass_hysteresis")
	store.set_slice(StringName("input"), {"look_input": Vector2(1.0, 0.0)})
	ecs_manager._physics_process(1.0)

	follow_target.global_position = Vector3(0.1, 0.0, 0.0)
	ecs_manager._physics_process(1.0)
	var bypass_state_all: Dictionary = system.get("_debug_position_smoothing_bypass_by_vcam") as Dictionary
	assert_true(bool(bypass_state_all.get(StringName("cam_orbit_bypass_hysteresis"), false)))

	follow_target.global_position = Vector3(0.38, 0.0, 0.0)
	ecs_manager._physics_process(1.0)
	bypass_state_all = system.get("_debug_position_smoothing_bypass_by_vcam") as Dictionary
	assert_true(
		bool(bypass_state_all.get(StringName("cam_orbit_bypass_hysteresis"), false)),
		"Bypass should remain enabled in the hysteresis band while previously active"
	)

	follow_target.global_position = Vector3(0.75, 0.0, 0.0)
	ecs_manager._physics_process(1.0)
	bypass_state_all = system.get("_debug_position_smoothing_bypass_by_vcam") as Dictionary
	assert_false(
		bool(bypass_state_all.get(StringName("cam_orbit_bypass_hysteresis"), true)),
		"Bypass should disable once speed exceeds the disable threshold"
	)

	follow_target.global_position = Vector3(1.02, 0.0, 0.0)
	ecs_manager._physics_process(1.0)
	bypass_state_all = system.get("_debug_position_smoothing_bypass_by_vcam") as Dictionary
	assert_false(
		bool(bypass_state_all.get(StringName("cam_orbit_bypass_hysteresis"), true)),
		"Bypass should stay disabled in the hysteresis band until speed falls below enable threshold"
	)

func test_orbit_look_release_does_not_pop_follow_position() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_OrbitReleaseTarget", Vector3.ZERO)
	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_release_handoff"),
		mode,
		follow_target
	)
	component.response = _new_response(1.0, 0.7, 1.0, 4.0, 1.0, 1.0)

	vcam_manager.active_vcam_id = StringName("cam_orbit_release_handoff")
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2(2.0, 0.0)})
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_orbit_release_handoff"))
	var look_state_all: Dictionary = system.get("_look_rotation_state") as Dictionary
	var look_state := look_state_all.get(StringName("cam_orbit_release_handoff"), {}) as Dictionary
	assert_false(look_state.is_empty(), "Look smoothing state should exist on release tick")
	var smoothed_yaw: float = float(look_state.get("smoothed_yaw", component.runtime_yaw))
	var smoothed_pitch: float = float(look_state.get("smoothed_pitch", component.runtime_pitch))
	var expected_result: Dictionary = U_VCAM_MODE_EVALUATOR.evaluate(
		mode,
		follow_target,
		component.get_look_at_target(),
		smoothed_yaw,
		smoothed_pitch
	)
	var expected_transform := expected_result.get("transform", Transform3D.IDENTITY) as Transform3D

	assert_almost_eq(
		submitted.origin.distance_to(expected_transform.origin),
		0.0,
		0.0001,
		"First frame after releasing orbit look input should not apply follow-position lag"
	)

	var follow_dynamics_all: Dictionary = system.get("_follow_dynamics") as Dictionary
	var follow_dynamics_variant: Variant = follow_dynamics_all.get(StringName("cam_orbit_release_handoff"), null)
	assert_true(follow_dynamics_variant is Object, "Follow dynamics should exist for orbit camera")
	var dynamics_object := follow_dynamics_variant as Object
	var cached_value_variant: Variant = dynamics_object.call("get_value")
	assert_true(cached_value_variant is Vector3, "Follow dynamics should expose Vector3 cached value")
	var cached_position := cached_value_variant as Vector3
	assert_almost_eq(
		cached_position.distance_to(expected_transform.origin),
		0.0,
		0.0001,
		"Follow dynamics cache should be reset to release-frame raw position"
	)

func test_response_smoothing_converges_toward_raw_pose_over_ticks() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_ConvergeTarget", Vector3.ZERO)
	var mode := _new_first_person_mode()
	var component := await _create_vcam_component(ecs_manager, StringName("cam_response_converge"), mode, follow_target)
	component.response = _new_response(3.0, 0.7, 1.0, 4.0, 1.0, 1.0)

	vcam_manager.active_vcam_id = StringName("cam_response_converge")
	ecs_manager._physics_process(0.016)

	follow_target.global_position = Vector3(10.0, 0.0, 0.0)
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var first_transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_response_converge"))
	var first_error: float = first_transform.origin.distance_to(raw_transform.origin)

	for _i in range(120):
		ecs_manager._physics_process(0.016)

	var final_transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_response_converge"))
	var final_error: float = final_transform.origin.distance_to(raw_transform.origin)

	assert_true(final_error < first_error, "Smoothed position should approach raw evaluator pose over time")
	assert_true(final_error < 0.05, "Smoothed position should settle close to raw evaluator pose")

func test_underdamped_follow_overshoots_then_settles() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_UnderdampedTarget", Vector3.ZERO)
	var mode := _new_first_person_mode()
	var component := await _create_vcam_component(ecs_manager, StringName("cam_response_under"), mode, follow_target)
	component.response = _new_response(2.0, 0.5, 1.0, 4.0, 1.0, 1.0)

	vcam_manager.active_vcam_id = StringName("cam_response_under")
	ecs_manager._physics_process(0.016)

	follow_target.global_position = Vector3(10.0, 0.0, 0.0)
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var raw_x: float = raw_transform.origin.x
	var max_x: float = -INF

	for _i in range(300):
		ecs_manager._physics_process(0.016)
		var sample: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_response_under"))
		max_x = maxf(max_x, sample.origin.x)

	var final_transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_response_under"))
	assert_true(max_x > raw_x + 0.01, "Underdamped follow should overshoot target position")
	assert_almost_eq(final_transform.origin.x, raw_x, 0.15)

func test_critical_damped_follow_does_not_overshoot() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_CriticalTarget", Vector3.ZERO)
	var mode := _new_first_person_mode()
	var component := await _create_vcam_component(ecs_manager, StringName("cam_response_critical"), mode, follow_target)
	component.response = _new_response(2.0, 1.0, 1.0, 4.0, 1.0, 1.0)

	vcam_manager.active_vcam_id = StringName("cam_response_critical")
	ecs_manager._physics_process(0.016)

	follow_target.global_position = Vector3(10.0, 0.0, 0.0)
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var raw_x: float = raw_transform.origin.x
	var max_x: float = -INF

	for _i in range(300):
		ecs_manager._physics_process(0.016)
		var sample: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_response_critical"))
		max_x = maxf(max_x, sample.origin.x)

	var final_transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_response_critical"))
	assert_true(max_x <= raw_x + 0.005, "Critically damped follow should avoid overshoot")
	assert_almost_eq(final_transform.origin.x, raw_x, 0.1)

func test_null_response_submits_raw_evaluator_output() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_NullResponseTarget", Vector3(3.0, 0.0, -1.0))
	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(ecs_manager, StringName("cam_null_response"), mode, follow_target)
	component.response = null

	vcam_manager.active_vcam_id = StringName("cam_null_response")
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_null_response"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D

	_assert_transform_close(submitted, raw_transform, 0.0001, 0.0001)

func test_rotation_smoothing_converges_to_evaluated_rotation() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_RotationTarget", Vector3.ZERO)
	var mode := _new_first_person_mode()
	var component := await _create_vcam_component(ecs_manager, StringName("cam_rotation_response"), mode, follow_target)
	component.response = _new_response(6.0, 1.0, 1.0, 1.0, 1.0, 1.0)

	vcam_manager.active_vcam_id = StringName("cam_rotation_response")
	ecs_manager._physics_process(0.016)

	component.runtime_yaw = 90.0
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var first_transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_rotation_response"))
	var first_error: float = _rotation_error(first_transform, raw_transform)

	for _i in range(180):
		ecs_manager._physics_process(0.016)

	var final_transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_rotation_response"))
	var final_error: float = _rotation_error(final_transform, raw_transform)

	assert_true(first_error > 0.001, "First frame after rotation change should be smoothed")
	assert_true(final_error < first_error, "Smoothed rotation should converge toward raw evaluator rotation")
	assert_true(final_error < 0.01, "Smoothed rotation should settle near raw evaluator rotation")

func test_mode_switch_resets_response_dynamics_without_residual_momentum() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_ModeSwitchTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_mode_reset"),
		_new_orbit_mode(),
		follow_target
	)
	component.response = _new_response(1.5, 0.7, 1.0, 1.5, 0.8, 1.0)

	vcam_manager.active_vcam_id = StringName("cam_mode_reset")
	ecs_manager._physics_process(0.016)

	follow_target.global_position = Vector3(9.0, 0.0, 0.0)
	for _i in range(8):
		ecs_manager._physics_process(0.016)

	component.mode = _new_first_person_mode()
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_mode_reset"))
	var raw_result: Dictionary = _evaluate_raw_result(component.mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D

	_assert_transform_close(submitted, raw_transform, 0.0001, 0.0001)

func test_follow_target_change_resets_response_dynamics() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var first_target := _create_target_entity(ecs_manager, "E_ResetTargetA", Vector3.ZERO)
	var second_target := _create_target_entity(ecs_manager, "E_ResetTargetB", Vector3(15.0, 0.0, 0.0))
	var mode := _new_first_person_mode()
	var component := await _create_vcam_component(ecs_manager, StringName("cam_target_reset"), mode, first_target)
	component.response = _new_response(1.5, 0.7, 1.0, 1.5, 0.8, 1.0)

	vcam_manager.active_vcam_id = StringName("cam_target_reset")
	ecs_manager._physics_process(0.016)

	first_target.global_position = Vector3(8.0, 0.0, 0.0)
	for _i in range(8):
		ecs_manager._physics_process(0.016)

	component.follow_target_path = second_target.get_path()
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_target_reset"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, second_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D

	_assert_transform_close(submitted, raw_transform, 0.0001, 0.0001)

func test_orbit_look_ahead_disabled_when_distance_is_zero() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_LookAheadDisabledTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_ahead_disabled"),
		_new_orbit_mode(),
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 1000.0, 1.0, 1.0, 0.0, 3.0)

	vcam_manager.active_vcam_id = StringName("cam_look_ahead_disabled")
	ecs_manager._physics_process(0.016)
	follow_target.global_position = Vector3(5.0, 0.0, 0.0)
	ecs_manager._physics_process(0.016)

	var look_ahead_state: Dictionary = system.get("_look_ahead_state") as Dictionary
	assert_false(
		look_ahead_state.has(StringName("cam_look_ahead_disabled")),
		"Look-ahead state should stay empty when distance is disabled"
	)

func test_orbit_look_ahead_applies_offset_in_movement_direction() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_LookAheadDirectionTarget", Vector3.ZERO)
	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_ahead_direction"),
		mode,
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 4.0, 1.0, 1.0, 2.0, 0.0)

	vcam_manager.active_vcam_id = StringName("cam_look_ahead_direction")
	ecs_manager._physics_process(0.016)

	_set_gameplay_entity_velocity(store, follow_target, Vector3(5.0, 0.0, 0.0))
	component.response.rotation_frequency = 4.1
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_look_ahead_direction"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var offset: Vector3 = submitted.origin - raw_transform.origin

	assert_true(offset.x > 1.9, "Look-ahead should shift orbit camera ahead in positive X when target moves +X")
	assert_almost_eq(offset.y, 0.0, 0.0001)
	assert_almost_eq(offset.z, 0.0, 0.0001)

func test_orbit_look_ahead_ignores_vertical_only_velocity() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_LookAheadVerticalOnlyTarget", Vector3.ZERO)
	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_ahead_vertical_only"),
		mode,
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 4.0, 1.0, 1.0, 2.0, 0.0)

	vcam_manager.active_vcam_id = StringName("cam_look_ahead_vertical_only")
	ecs_manager._physics_process(0.016)

	_set_gameplay_entity_velocity(store, follow_target, Vector3(0.0, -5.0, 0.0))
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_look_ahead_vertical_only"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var offset: Vector3 = submitted.origin - raw_transform.origin

	assert_almost_eq(offset.length(), 0.0, 0.0001)

func test_orbit_look_ahead_does_not_apply_while_look_input_is_active() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var system: S_VCamSystem = context["system"] as S_VCamSystem
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_LookAheadWhileRotatingTarget", Vector3.ZERO)
	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_ahead_while_rotating"),
		mode,
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 4.0, 1.0, 1.0, 2.0, 0.0)

	vcam_manager.active_vcam_id = StringName("cam_look_ahead_while_rotating")
	ecs_manager._physics_process(0.016)

	_set_gameplay_entity_velocity(store, follow_target, Vector3(5.0, 0.0, 0.0))
	store.set_slice(StringName("input"), {"look_input": Vector2(1.0, 0.0)})
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	var look_ahead_state: Dictionary = system.get("_look_ahead_state") as Dictionary
	assert_false(
		look_ahead_state.has(StringName("cam_look_ahead_while_rotating")),
		"Look-ahead state should clear while camera rotation input is active"
	)

func test_orbit_look_ahead_offset_magnitude_is_clamped_to_distance() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_LookAheadClampTarget", Vector3.ZERO)
	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_ahead_clamp"),
		mode,
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 4.0, 1.0, 1.0, 1.25, 0.0)

	vcam_manager.active_vcam_id = StringName("cam_look_ahead_clamp")
	ecs_manager._physics_process(0.016)

	_set_gameplay_entity_velocity(store, follow_target, Vector3(100.0, 0.0, 0.0))
	component.response.rotation_frequency = 4.1
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_look_ahead_clamp"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var offset_length: float = (submitted.origin - raw_transform.origin).length()

	assert_true(offset_length <= 1.2501)
	assert_true(offset_length >= 1.2)

func test_orbit_look_ahead_stationary_target_keeps_zero_offset() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var system: S_VCamSystem = context["system"] as S_VCamSystem
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_LookAheadStationaryTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_ahead_stationary"),
		_new_orbit_mode(),
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 4.0, 1.0, 1.0, 2.0, 0.0)
	_set_gameplay_entity_velocity(store, follow_target, Vector3.ZERO, false)

	vcam_manager.active_vcam_id = StringName("cam_look_ahead_stationary")
	ecs_manager._physics_process(0.016)
	ecs_manager._physics_process(0.016)

	var look_ahead_state: Dictionary = system.get("_look_ahead_state") as Dictionary
	var state := look_ahead_state.get(StringName("cam_look_ahead_stationary"), {}) as Dictionary
	var offset := state.get("current_offset", Vector3.ONE) as Vector3
	assert_true(offset.is_zero_approx())

func test_orbit_look_ahead_clears_offset_when_target_stops() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var system: S_VCamSystem = context["system"] as S_VCamSystem
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_LookAheadStopTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_ahead_stop"),
		_new_orbit_mode(),
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 4.0, 1.0, 1.0, 2.0, 0.0)

	vcam_manager.active_vcam_id = StringName("cam_look_ahead_stop")
	ecs_manager._physics_process(0.016)

	_set_gameplay_entity_velocity(store, follow_target, Vector3(5.0, 0.0, 0.0))
	ecs_manager._physics_process(0.016)

	var moving_state_all: Dictionary = system.get("_look_ahead_state") as Dictionary
	var moving_state := moving_state_all.get(StringName("cam_look_ahead_stop"), {}) as Dictionary
	var moving_offset := moving_state.get("current_offset", Vector3.ZERO) as Vector3
	assert_true(
		moving_offset.length() > 1.9,
		"Look-ahead offset should be non-zero while target is moving"
	)

	_set_gameplay_entity_velocity(store, follow_target, Vector3.ZERO, false)
	ecs_manager._physics_process(0.016)

	var stopped_state_all: Dictionary = system.get("_look_ahead_state") as Dictionary
	var stopped_state := stopped_state_all.get(StringName("cam_look_ahead_stop"), {}) as Dictionary
	var stopped_offset := stopped_state.get("current_offset", Vector3.ONE) as Vector3
	assert_true(
		stopped_offset.is_zero_approx(),
		"Look-ahead offset should clear when target stops moving"
	)

func test_orbit_look_ahead_clears_state_on_mode_switch() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var system: S_VCamSystem = context["system"] as S_VCamSystem
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_LookAheadModeSwitchTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_ahead_mode_switch"),
		_new_orbit_mode(),
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 4.0, 1.0, 1.0, 2.0, 0.0)

	vcam_manager.active_vcam_id = StringName("cam_look_ahead_mode_switch")
	ecs_manager._physics_process(0.016)
	_set_gameplay_entity_velocity(store, follow_target, Vector3(5.0, 0.0, 0.0))
	component.response.rotation_frequency = 4.1
	ecs_manager._physics_process(0.016)

	var pre_switch_state: Dictionary = system.get("_look_ahead_state") as Dictionary
	assert_true(pre_switch_state.has(StringName("cam_look_ahead_mode_switch")))

	component.mode = _new_first_person_mode()
	ecs_manager._physics_process(0.016)

	var post_switch_state: Dictionary = system.get("_look_ahead_state") as Dictionary
	assert_false(post_switch_state.has(StringName("cam_look_ahead_mode_switch")))

func test_orbit_look_ahead_resets_when_follow_target_changes() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var system: S_VCamSystem = context["system"] as S_VCamSystem
	var store: MockStateStore = context["store"] as MockStateStore

	var first_target := _create_target_entity(ecs_manager, "E_LookAheadResetTargetA", Vector3.ZERO)
	var second_target := _create_target_entity(ecs_manager, "E_LookAheadResetTargetB", Vector3(10.0, 0.0, 0.0))
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_ahead_reset"),
		_new_orbit_mode(),
		first_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 4.0, 1.0, 1.0, 2.0, 3.0)

	vcam_manager.active_vcam_id = StringName("cam_look_ahead_reset")
	ecs_manager._physics_process(0.016)
	_set_gameplay_entity_velocity(store, first_target, Vector3(6.0, 0.0, 0.0))
	ecs_manager._physics_process(0.016)

	_set_gameplay_entity_velocity(store, second_target, Vector3.ZERO, false)
	component.follow_target_path = second_target.get_path()
	ecs_manager._physics_process(0.016)

	var look_ahead_state: Dictionary = system.get("_look_ahead_state") as Dictionary
	var state_variant: Variant = look_ahead_state.get(StringName("cam_look_ahead_reset"), {})
	assert_true(state_variant is Dictionary)
	var state := state_variant as Dictionary
	assert_eq(int(state.get("follow_target_id", 0)), second_target.get_instance_id())
	var current_offset := state.get("current_offset", Vector3.ONE) as Vector3
	assert_true(current_offset.is_zero_approx(), "Target swap should reset look-ahead offset state")

func test_orbit_look_ahead_is_noop_for_first_person_mode() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_LookAheadFPModeTarget", Vector3.ZERO)
	var mode := _new_first_person_mode()
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_ahead_fp"),
		mode,
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 4.0, 1.0, 1.0, 2.0, 0.0)

	vcam_manager.active_vcam_id = StringName("cam_look_ahead_fp")
	ecs_manager._physics_process(0.016)
	follow_target.global_position = Vector3(5.0, 0.0, 0.0)
	component.response.rotation_frequency = 4.1
	ecs_manager._physics_process(0.016)

	var look_ahead_state: Dictionary = system.get("_look_ahead_state") as Dictionary
	assert_false(look_ahead_state.has(StringName("cam_look_ahead_fp")))

func test_orbit_look_ahead_ignores_rotation_only_target_motion() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_entity := _create_target_entity(ecs_manager, "E_LookAheadRotationOnlyTarget", Vector3.ZERO)
	var follow_marker := Node3D.new()
	follow_marker.name = "FollowMarker"
	follow_marker.position = Vector3(0.0, 0.0, 1.5)
	follow_entity.add_child(follow_marker)
	autofree(follow_marker)
	await _pump()

	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_ahead_rotation_only"),
		mode,
		follow_marker
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 4.0, 1.0, 1.0, 2.0, 0.0)

	vcam_manager.active_vcam_id = StringName("cam_look_ahead_rotation_only")
	_set_gameplay_entity_velocity(store, follow_entity, Vector3.ZERO, false)
	ecs_manager._physics_process(0.016)

	follow_entity.rotate_y(PI * 0.5)
	component.response.rotation_frequency = 4.1
	vcam_manager.clear_submissions()
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_look_ahead_rotation_only"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_marker, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var offset: Vector3 = submitted.origin - raw_transform.origin
	assert_true(
		offset.is_zero_approx(),
		"Look-ahead should remain zero when target rotates in place without movement velocity"
	)

func test_orbit_auto_level_disabled_when_speed_is_zero() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_AutoLevelDisabledTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_auto_level_disabled"),
		_new_orbit_mode(true, 0.0),
		follow_target
	)
	component.response = _new_response(3.0, 0.7, 1.0, 4.0, 1.0, 1.0, 0.0, 3.0, 0.0, 0.0)
	component.runtime_pitch = 24.0

	vcam_manager.active_vcam_id = StringName("cam_auto_level_disabled")
	for _i in range(120):
		ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_pitch, 24.0, 0.0001)

func test_orbit_auto_level_decays_pitch_after_delay() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_AutoLevelDecayTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_auto_level_decay"),
		_new_orbit_mode(true, 0.0),
		follow_target
	)
	component.response = _new_response(3.0, 0.7, 1.0, 4.0, 1.0, 1.0, 0.0, 3.0, 40.0, 0.2)
	component.runtime_pitch = 30.0

	vcam_manager.active_vcam_id = StringName("cam_auto_level_decay")
	for _i in range(8):
		ecs_manager._physics_process(0.016)
	assert_almost_eq(component.runtime_pitch, 30.0, 0.0001)

	for _j in range(24):
		ecs_manager._physics_process(0.016)
	assert_true(component.runtime_pitch < 30.0)
	assert_true(component.runtime_pitch > 0.0)

func test_orbit_auto_level_does_not_activate_while_look_input_is_active() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_AutoLevelInputTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_auto_level_input"),
		_new_orbit_mode(true, 0.0),
		follow_target
	)
	component.response = _new_response(3.0, 0.7, 1.0, 4.0, 1.0, 1.0, 0.0, 3.0, 30.0, 0.0)
	component.runtime_pitch = 18.0

	store.set_slice(StringName("input"), {"look_input": Vector2(0.2, 0.0)})
	vcam_manager.active_vcam_id = StringName("cam_auto_level_input")
	for _i in range(120):
		ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_pitch, 18.0, 0.0001)

func test_orbit_auto_level_delay_timer_resets_when_look_input_resumes() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_AutoLevelTimerTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_auto_level_timer"),
		_new_orbit_mode(true, 0.0),
		follow_target
	)
	component.response = _new_response(3.0, 0.7, 1.0, 4.0, 1.0, 1.0, 0.0, 3.0, 30.0, 0.15)
	component.runtime_pitch = 20.0

	vcam_manager.active_vcam_id = StringName("cam_auto_level_timer")
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	for _i in range(8):
		ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2(1.0, 0.0)})
	ecs_manager._physics_process(0.016)

	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	for _j in range(8):
		ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_pitch, 20.0, 0.0001)

func test_orbit_auto_level_respects_speed_degrees_per_second() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_AutoLevelRateTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_auto_level_rate"),
		_new_orbit_mode(true, 0.0),
		follow_target
	)
	component.response = _new_response(3.0, 0.7, 1.0, 4.0, 1.0, 1.0, 0.0, 3.0, 30.0, 0.0)
	component.runtime_pitch = 45.0

	vcam_manager.active_vcam_id = StringName("cam_auto_level_rate")
	for _i in range(60):
		ecs_manager._physics_process(0.016)

	assert_almost_eq(component.runtime_pitch, 16.2, 0.6)

func test_orbit_auto_level_is_noop_for_first_person_and_fixed_modes() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_AutoLevelModeTarget", Vector3.ZERO)
	var fp_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_auto_level_fp"),
		_new_first_person_mode(),
		follow_target
	)
	fp_component.response = _new_response(3.0, 0.7, 1.0, 4.0, 1.0, 1.0, 0.0, 3.0, 30.0, 0.0)
	fp_component.runtime_pitch = 12.0

	var fixed_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_auto_level_fixed"),
		RS_VCAM_MODE_FIXED.new(),
		follow_target
	)
	fixed_component.response = _new_response(3.0, 0.7, 1.0, 4.0, 1.0, 1.0, 0.0, 3.0, 30.0, 0.0)
	fixed_component.runtime_pitch = -9.0

	vcam_manager.active_vcam_id = StringName("cam_auto_level_fp")
	for _i in range(90):
		ecs_manager._physics_process(0.016)
	assert_almost_eq(fp_component.runtime_pitch, 12.0, 0.0001)

	vcam_manager.active_vcam_id = StringName("cam_auto_level_fixed")
	for _j in range(90):
		ecs_manager._physics_process(0.016)
	assert_almost_eq(fixed_component.runtime_pitch, -9.0, 0.0001)

func test_orbit_soft_zone_applies_correction_when_resource_is_present() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	_create_projection_camera()
	await _pump()
	var follow_target := _create_target_entity(ecs_manager, "E_SoftZoneFollow", Vector3.ZERO)
	var look_target := _create_target_entity(ecs_manager, "E_SoftZoneLook", Vector3(10.0, 0.0, -10.0))
	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(ecs_manager, StringName("cam_soft_zone_enabled"), mode, follow_target)
	component.look_at_target_path = look_target.get_path()
	component.soft_zone = _new_soft_zone(0.1, 0.1, 0.4, 0.4, 20.0)
	component.response = null

	vcam_manager.active_vcam_id = StringName("cam_soft_zone_enabled")
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_soft_zone_enabled"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_true(submitted.origin.distance_to(raw_transform.origin) > 0.001)

func test_orbit_soft_zone_noops_when_resource_is_missing() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	_create_projection_camera()
	await _pump()
	var follow_target := _create_target_entity(ecs_manager, "E_SoftZoneNoResFollow", Vector3.ZERO)
	var look_target := _create_target_entity(ecs_manager, "E_SoftZoneNoResLook", Vector3(10.0, 0.0, -10.0))
	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(ecs_manager, StringName("cam_soft_zone_disabled"), mode, follow_target)
	component.look_at_target_path = look_target.get_path()
	component.soft_zone = null
	component.response = null

	vcam_manager.active_vcam_id = StringName("cam_soft_zone_disabled")
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_soft_zone_disabled"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	_assert_transform_close(submitted, raw_transform, 0.0001, 0.0001)

func test_soft_zone_is_noop_for_first_person_mode() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	_create_projection_camera()
	await _pump()
	var follow_target := _create_target_entity(ecs_manager, "E_SoftZoneFirstPersonFollow", Vector3.ZERO)
	var mode := _new_first_person_mode()
	var component := await _create_vcam_component(ecs_manager, StringName("cam_soft_zone_first_person"), mode, follow_target)
	component.soft_zone = _new_soft_zone(0.1, 0.1, 0.4, 0.4, 20.0)
	component.response = null

	vcam_manager.active_vcam_id = StringName("cam_soft_zone_first_person")
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_soft_zone_first_person"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	_assert_transform_close(submitted, raw_transform, 0.0001, 0.0001)

func test_orbit_ground_relative_jump_bob_suppression_while_airborne() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_GroundRelativeJumpTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ground_relative_jump"),
		_new_orbit_mode(),
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 1000.0, 1.0, 1.0)
	component.response.set("ground_relative_enabled", true)
	component.response.set("ground_reanchor_min_height_delta", 0.5)
	component.response.set("ground_anchor_blend_hz", 0.0)

	_set_gameplay_entity_floor_state(store, follow_target, true)
	vcam_manager.active_vcam_id = StringName("cam_ground_relative_jump")
	ecs_manager._physics_process(0.016)
	var baseline_transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ground_relative_jump"))

	_set_gameplay_entity_floor_state(store, follow_target, false)
	follow_target.global_position = Vector3(0.0, 2.5, 0.0)
	ecs_manager._physics_process(0.016)
	var airborne_transform: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ground_relative_jump"))

	assert_almost_eq(airborne_transform.origin.y, baseline_transform.origin.y, 0.001)

func test_orbit_ground_relative_airborne_vertical_lock_prevents_per_frame_y_chase() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_GroundRelativeAirborneLockTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ground_relative_airborne_lock"),
		_new_orbit_mode(),
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 1000.0, 1.0, 1.0)
	component.response.set("ground_relative_enabled", true)
	component.response.set("ground_reanchor_min_height_delta", 0.5)
	component.response.set("ground_anchor_blend_hz", 0.0)

	_set_gameplay_entity_floor_state(store, follow_target, true)
	vcam_manager.active_vcam_id = StringName("cam_ground_relative_airborne_lock")
	ecs_manager._physics_process(0.016)
	var baseline_y: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ground_relative_airborne_lock")
	).origin.y

	_set_gameplay_entity_floor_state(store, follow_target, false)
	var airborne_heights: Array[float] = [1.5, 2.2, 3.1, 4.0]
	for height in airborne_heights:
		follow_target.global_position = Vector3(0.0, height, 0.0)
		ecs_manager._physics_process(0.016)
		var current_y: float = _extract_submission_transform(
			vcam_manager,
			StringName("cam_ground_relative_airborne_lock")
		).origin.y
		assert_almost_eq(current_y, baseline_y, 0.001)

func test_orbit_ground_relative_minor_landing_height_delta_does_not_reanchor() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_GroundRelativeMinorLandingTarget", Vector3.ZERO)
	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ground_relative_minor_landing"),
		mode,
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 1000.0, 1.0, 1.0)
	component.response.set("ground_relative_enabled", true)
	component.response.set("ground_reanchor_min_height_delta", 0.5)
	component.response.set("ground_anchor_blend_hz", 0.0)

	_set_gameplay_entity_floor_state(store, follow_target, true)
	vcam_manager.active_vcam_id = StringName("cam_ground_relative_minor_landing")
	ecs_manager._physics_process(0.016)
	var baseline_y: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ground_relative_minor_landing")
	).origin.y

	_set_gameplay_entity_floor_state(store, follow_target, false)
	follow_target.global_position = Vector3(0.0, 1.2, 0.0)
	ecs_manager._physics_process(0.016)

	_set_gameplay_entity_floor_state(store, follow_target, true)
	follow_target.global_position = Vector3(0.0, 0.3, 0.0)
	ecs_manager._physics_process(0.016)
	var landed_transform: Transform3D = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ground_relative_minor_landing")
	)
	var raw_transform := _evaluate_raw_result(mode, follow_target, component).get(
		"transform",
		Transform3D.IDENTITY
	) as Transform3D

	assert_almost_eq(landed_transform.origin.y, baseline_y, 0.001)
	assert_true(
		absf(raw_transform.origin.y - baseline_y) > 0.2,
		"Minor landing should keep prior anchor instead of snapping to raw follow height"
	)

func test_orbit_ground_relative_major_landing_height_delta_reanchors_smoothly() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_GroundRelativeMajorLandingTarget", Vector3.ZERO)
	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ground_relative_major_landing"),
		mode,
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 1000.0, 1.0, 1.0)
	component.response.set("ground_relative_enabled", true)
	component.response.set("ground_reanchor_min_height_delta", 0.5)
	component.response.set("ground_anchor_blend_hz", 4.0)

	_set_gameplay_entity_floor_state(store, follow_target, true)
	vcam_manager.active_vcam_id = StringName("cam_ground_relative_major_landing")
	ecs_manager._physics_process(0.016)
	var baseline_y: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ground_relative_major_landing")
	).origin.y

	_set_gameplay_entity_floor_state(store, follow_target, false)
	follow_target.global_position = Vector3(0.0, 1.4, 0.0)
	ecs_manager._physics_process(0.016)

	_set_gameplay_entity_floor_state(store, follow_target, true)
	follow_target.global_position = Vector3(0.0, 2.0, 0.0)
	ecs_manager._physics_process(0.016)
	var first_landing_y: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ground_relative_major_landing")
	).origin.y
	var target_y: float = (_evaluate_raw_result(mode, follow_target, component).get(
		"transform",
		Transform3D.IDENTITY
	) as Transform3D).origin.y

	for _i in range(30):
		ecs_manager._physics_process(0.016)
	var early_reanchor_y: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ground_relative_major_landing")
	).origin.y

	assert_true(
		first_landing_y <= target_y,
		"Landing tick should not overshoot the new target anchor height"
	)
	assert_true(
		first_landing_y < target_y,
		"Re-anchor should not snap to the final target on the landing tick"
	)
	assert_true(
		early_reanchor_y > baseline_y,
		"Major landing should move upward toward the new anchor over early re-anchor frames"
	)

	for _i in range(240):
		ecs_manager._physics_process(0.016)
	var settled_y: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ground_relative_major_landing")
	).origin.y
	assert_almost_eq(settled_y, target_y, 0.03)

func test_orbit_ground_relative_uneven_ground_stays_stable_without_micro_bob() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_GroundRelativeUnevenTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ground_relative_uneven"),
		_new_orbit_mode(),
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 1000.0, 1.0, 1.0)
	component.response.set("ground_relative_enabled", true)
	component.response.set("ground_reanchor_min_height_delta", 0.5)
	component.response.set("ground_anchor_blend_hz", 4.0)

	_set_gameplay_entity_floor_state(store, follow_target, true)
	vcam_manager.active_vcam_id = StringName("cam_ground_relative_uneven")
	ecs_manager._physics_process(0.016)
	var baseline_y: float = _extract_submission_transform(vcam_manager, StringName("cam_ground_relative_uneven")).origin.y

	var short_step_heights: Array[float] = [0.1, 0.2, 0.25, 0.35, 0.45]
	var max_drift: float = 0.0
	for height in short_step_heights:
		follow_target.global_position = Vector3(0.0, height, 0.0)
		_set_gameplay_entity_floor_state(store, follow_target, true)
		ecs_manager._physics_process(0.016)
		var current_y: float = _extract_submission_transform(vcam_manager, StringName("cam_ground_relative_uneven")).origin.y
		max_drift = maxf(max_drift, absf(current_y - baseline_y))

	assert_true(max_drift < 0.03, "Small uneven-ground traversal should not introduce vertical micro-bob")

func test_ground_relative_is_strict_noop_for_non_orbit_modes() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var system: S_VCamSystem = context["system"] as S_VCamSystem
	var store: MockStateStore = context["store"] as MockStateStore

	var follow_target := _create_target_entity(ecs_manager, "E_GroundRelativeNoopModeTarget", Vector3.ZERO)
	var mode := _new_first_person_mode()
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ground_relative_noop_mode"),
		mode,
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 1000.0, 1.0, 1.0)
	component.response.set("ground_relative_enabled", true)
	component.response.set("ground_reanchor_min_height_delta", 0.5)
	component.response.set("ground_anchor_blend_hz", 4.0)

	_set_gameplay_entity_floor_state(store, follow_target, true)
	vcam_manager.active_vcam_id = StringName("cam_ground_relative_noop_mode")
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ground_relative_noop_mode"))
	var raw_transform := _evaluate_raw_result(mode, follow_target, component).get(
		"transform",
		Transform3D.IDENTITY
	) as Transform3D
	_assert_transform_close(submitted, raw_transform, 0.0001, 0.0001)

	var ground_relative_state: Dictionary = system.get("_ground_relative_state") as Dictionary
	assert_false(
		ground_relative_state.has(StringName("cam_ground_relative_noop_mode")),
		"Ground-relative state must not be created for non-orbit modes"
	)

func test_orbit_ground_relative_reanchors_after_airborne_spawn_then_floor_to_platform() -> void:
	# Regression: initialization mid-air set last_ground_reference_y to follow_y at spawn (0.0),
	# so floor-to-platform height deltas were always compared against that stale baseline and
	# always fell below the threshold — the camera anchor never updated after landing anywhere.
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	# Spawn at Y=0, airborne — matches the real bug's starting condition.
	var follow_target := _create_target_entity(ecs_manager, "E_GroundRelativeSpawnAirborneTarget", Vector3.ZERO)
	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_gr_spawn_airborne"),
		mode,
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 1000.0, 1.0, 1.0)
	component.response.set("ground_relative_enabled", true)
	component.response.set("ground_reanchor_min_height_delta", 1.0)
	component.response.set("ground_anchor_blend_hz", 0.0)

	# Tick while airborne — state should not initialize yet.
	_set_gameplay_entity_floor_state(store, follow_target, false)
	vcam_manager.active_vcam_id = StringName("cam_gr_spawn_airborne")
	ecs_manager._physics_process(0.016)

	# Land on floor at Y=0 — first real grounded contact, anchor initializes to 0.0.
	follow_target.global_position = Vector3(0.0, 0.0, 0.0)
	_set_gameplay_entity_floor_state(store, follow_target, true)
	ecs_manager._physics_process(0.016)
	var floor_y: float = _extract_submission_transform(vcam_manager, StringName("cam_gr_spawn_airborne")).origin.y

	# Jump (airborne).
	_set_gameplay_entity_floor_state(store, follow_target, false)
	follow_target.global_position = Vector3(0.0, 1.5, 0.0)
	ecs_manager._physics_process(0.016)

	# Land on elevated platform at Y=2.0 — delta from floor (0.0) is 2.0 >= threshold (1.0),
	# so camera must re-anchor to the new surface.
	follow_target.global_position = Vector3(0.0, 2.0, 0.0)
	_set_gameplay_entity_floor_state(store, follow_target, true)
	# Run enough ticks for the follow dynamics to settle at the new anchor position.
	# (Semi-implicit Euler at 1000Hz needs several ticks to converge from rest.)
	for _i in range(60):
		ecs_manager._physics_process(0.016)
	var platform_y: float = _extract_submission_transform(vcam_manager, StringName("cam_gr_spawn_airborne")).origin.y

	assert_true(
		platform_y > floor_y + 0.5,
		"Camera must re-anchor when landing on a platform 2.0m above the floor (got floor_y=%.3f platform_y=%.3f)" % [floor_y, platform_y]
	)

func test_orbit_ground_relative_first_grounded_contact_after_airborne_descent_has_no_large_vertical_pop() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore

	var ground := StaticBody3D.new()
	ground.name = "GroundProbeSurface"
	add_child(ground)
	autofree(ground)
	ground.global_position = Vector3(0.0, -1.0, 0.0)

	var ground_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(30.0, 0.1, 30.0)
	ground_shape.shape = box_shape
	ground.add_child(ground_shape)
	autofree(ground_shape)
	await _pump()
	await _pump()

	var follow_target := _create_target_entity(ecs_manager, "E_GroundRelativeFirstContactTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ground_relative_first_contact"),
		_new_orbit_mode(),
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 1000.0, 1.0, 1.0)
	component.response.set("ground_relative_enabled", true)
	component.response.set("ground_reanchor_min_height_delta", 0.5)
	component.response.set("ground_probe_max_distance", 12.0)
	component.response.set("ground_anchor_blend_hz", 4.0)

	_set_gameplay_entity_floor_state(store, follow_target, false)
	vcam_manager.active_vcam_id = StringName("cam_ground_relative_first_contact")

	var airborne_heights: Array[float] = [-0.01667, -0.05000, -0.10000, -0.13832, -0.16852, -0.19273]
	for height in airborne_heights:
		follow_target.global_position = Vector3(0.0, height, 0.0)
		ecs_manager._physics_process(0.016)

	var pre_landing_transform: Transform3D = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ground_relative_first_contact")
	)

	_set_gameplay_entity_floor_state(store, follow_target, true)
	follow_target.global_position = Vector3(0.0, -0.21231, 0.0)
	ecs_manager._physics_process(0.016)
	var first_grounded_transform: Transform3D = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ground_relative_first_contact")
	)

	var vertical_step: float = first_grounded_transform.origin.y - pre_landing_transform.origin.y
	assert_true(
		absf(vertical_step) < 0.12,
		"First grounded tick should not apply a large vertical correction (step=%.5f)" % [vertical_step]
	)

func test_ots_landing_camera_response_is_disabled_when_dip_distance_is_zero() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_OTSLandingDisabledTarget", Vector3.ZERO)
	var mode := _new_ots_mode(1.0)
	mode.shoulder_offset = Vector3.ZERO
	mode.camera_distance = 4.0
	mode.landing_dip_distance = 0.0
	mode.landing_dip_recovery_speed = 8.0
	var component := await _create_vcam_component(ecs_manager, StringName("cam_ots_landing_disabled"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_landing_disabled")
	ecs_manager._physics_process(0.016)
	_publish_player_landing_event(30.0)
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ots_landing_disabled"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	_assert_transform_close(submitted, raw_transform, 0.0001, 0.0001)

func test_ots_landing_camera_response_reduces_distance_on_landing_event() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_OTSLandingReduceTarget", Vector3.ZERO)
	var mode := _new_ots_mode(1.0)
	mode.shoulder_offset = Vector3.ZERO
	mode.camera_distance = 4.0
	mode.landing_dip_distance = 0.8
	mode.landing_dip_recovery_speed = 6.0
	await _create_vcam_component(ecs_manager, StringName("cam_ots_landing_reduce"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_landing_reduce")
	ecs_manager._physics_process(0.016)
	var baseline_distance: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ots_landing_reduce")
	).origin.distance_to(follow_target.global_position)

	_publish_player_landing_event(30.0)
	ecs_manager._physics_process(0.016)
	var dipped_distance: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ots_landing_reduce")
	).origin.distance_to(follow_target.global_position)

	assert_true(dipped_distance < baseline_distance)
	assert_true(dipped_distance <= (baseline_distance - 0.3))

func test_ots_landing_camera_response_scales_with_fall_speed() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_OTSLandingScaleTarget", Vector3.ZERO)
	var mode := _new_ots_mode(1.0)
	mode.shoulder_offset = Vector3.ZERO
	mode.camera_distance = 4.0
	mode.landing_dip_distance = 1.0
	mode.landing_dip_recovery_speed = 8.0
	await _create_vcam_component(ecs_manager, StringName("cam_ots_landing_scale"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_landing_scale")
	ecs_manager._physics_process(0.016)

	_publish_player_landing_event(10.0)
	ecs_manager._physics_process(0.016)
	var low_speed_distance: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ots_landing_scale")
	).origin.distance_to(follow_target.global_position)

	_publish_player_landing_event(30.0)
	ecs_manager._physics_process(0.016)
	var high_speed_distance: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ots_landing_scale")
	).origin.distance_to(follow_target.global_position)

	assert_true(high_speed_distance < low_speed_distance)

func test_ots_landing_camera_response_recovers_toward_normal_distance() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_OTSLandingRecoverTarget", Vector3.ZERO)
	var mode := _new_ots_mode(1.0)
	mode.shoulder_offset = Vector3.ZERO
	mode.camera_distance = 4.0
	mode.landing_dip_distance = 0.8
	mode.landing_dip_recovery_speed = 4.0
	await _create_vcam_component(ecs_manager, StringName("cam_ots_landing_recover"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_landing_recover")
	ecs_manager._physics_process(0.016)
	var baseline_distance: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ots_landing_recover")
	).origin.distance_to(follow_target.global_position)

	_publish_player_landing_event(30.0)
	ecs_manager._physics_process(0.016)
	var dipped_distance: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ots_landing_recover")
	).origin.distance_to(follow_target.global_position)

	for _i in range(180):
		ecs_manager._physics_process(0.016)
	var recovered_distance: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ots_landing_recover")
	).origin.distance_to(follow_target.global_position)

	assert_true(dipped_distance < baseline_distance)
	assert_true(recovered_distance > dipped_distance)
	assert_almost_eq(recovered_distance, baseline_distance, 0.05)

func test_ots_landing_camera_response_recovery_is_critically_damped_without_overshoot() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_OTSLandingDampedTarget", Vector3.ZERO)
	var mode := _new_ots_mode(1.0)
	mode.shoulder_offset = Vector3.ZERO
	mode.camera_distance = 4.0
	mode.landing_dip_distance = 1.0
	mode.landing_dip_recovery_speed = 6.0
	await _create_vcam_component(ecs_manager, StringName("cam_ots_landing_damped"), mode, follow_target)

	vcam_manager.active_vcam_id = StringName("cam_ots_landing_damped")
	ecs_manager._physics_process(0.016)
	var baseline_distance: float = _extract_submission_transform(
		vcam_manager,
		StringName("cam_ots_landing_damped")
	).origin.distance_to(follow_target.global_position)

	_publish_player_landing_event(30.0)
	var max_distance: float = -INF
	for _i in range(180):
		ecs_manager._physics_process(0.016)
		var distance_now: float = _extract_submission_transform(
			vcam_manager,
			StringName("cam_ots_landing_damped")
		).origin.distance_to(follow_target.global_position)
		max_distance = maxf(max_distance, distance_now)

	assert_true(max_distance <= (baseline_distance + 0.001))
	assert_almost_eq(
		_extract_submission_transform(vcam_manager, StringName("cam_ots_landing_damped")).origin.distance_to(
			follow_target.global_position
		),
		baseline_distance,
		0.05
	)

func test_ots_landing_camera_response_stacks_with_shared_landing_impact_offset() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_OTSLandingStackTarget", Vector3.ZERO)
	var mode := _new_ots_mode(1.0)
	mode.shoulder_offset = Vector3.ZERO
	mode.camera_distance = 4.0
	mode.landing_dip_distance = 0.8
	mode.landing_dip_recovery_speed = 6.0
	var component := await _create_vcam_component(ecs_manager, StringName("cam_ots_landing_stack"), mode, follow_target)
	_create_camera_state_component(ecs_manager, Vector3(0.0, -0.3, 0.0), 0.0)

	vcam_manager.active_vcam_id = StringName("cam_ots_landing_stack")
	ecs_manager._physics_process(0.016)
	_publish_player_landing_event(30.0)
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ots_landing_stack"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	var raw_planar_distance: float = Vector2(raw_transform.origin.x, raw_transform.origin.z).length()
	var submitted_planar_distance: float = Vector2(submitted.origin.x, submitted.origin.z).length()

	assert_almost_eq(submitted.origin.y, raw_transform.origin.y - 0.3, 0.01)
	assert_true(submitted_planar_distance < raw_planar_distance)

func test_ots_landing_camera_response_is_noop_for_orbit_and_fixed_modes() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var orbit_target := _create_target_entity(ecs_manager, "E_OTSLandingNoopOrbitTarget", Vector3.ZERO)
	var orbit_mode := _new_orbit_mode(false, 0.0)
	var orbit_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ots_landing_noop_orbit"),
		orbit_mode,
		orbit_target
	)
	vcam_manager.active_vcam_id = StringName("cam_ots_landing_noop_orbit")
	ecs_manager._physics_process(0.016)
	_publish_player_landing_event(30.0)
	ecs_manager._physics_process(0.016)
	var orbit_submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ots_landing_noop_orbit"))
	var orbit_raw := _evaluate_raw_result(orbit_mode, orbit_target, orbit_component).get(
		"transform",
		Transform3D.IDENTITY
	) as Transform3D
	_assert_transform_close(orbit_submitted, orbit_raw, 0.0001, 0.0001)

	var fixed_target := _create_target_entity(ecs_manager, "E_OTSLandingNoopFixedTarget", Vector3.ZERO)
	var fixed_mode := RS_VCAM_MODE_FIXED.new()
	fixed_mode.use_world_anchor = false
	fixed_mode.follow_offset = Vector3(0.0, 0.0, 4.0)
	fixed_mode.track_target = false
	var fixed_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_ots_landing_noop_fixed"),
		fixed_mode,
		fixed_target
	)
	vcam_manager.active_vcam_id = StringName("cam_ots_landing_noop_fixed")
	ecs_manager._physics_process(0.016)
	_publish_player_landing_event(30.0)
	ecs_manager._physics_process(0.016)
	var fixed_submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_ots_landing_noop_fixed"))
	var fixed_raw := _evaluate_raw_result(fixed_mode, fixed_target, fixed_component).get(
		"transform",
		Transform3D.IDENTITY
	) as Transform3D
	_assert_transform_close(fixed_submitted, fixed_raw, 0.0001, 0.0001)

func test_landing_impact_offset_is_added_to_submitted_position() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_LandingImpactTarget", Vector3.ZERO)
	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(ecs_manager, StringName("cam_landing_offset"), mode, follow_target)
	_create_camera_state_component(ecs_manager, Vector3(0.0, -0.3, 0.0), 0.0)

	vcam_manager.active_vcam_id = StringName("cam_landing_offset")
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_landing_offset"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	assert_almost_eq(submitted.origin.x, raw_transform.origin.x, 0.0001)
	assert_almost_eq(submitted.origin.y, raw_transform.origin.y - 0.3, 0.0001)
	assert_almost_eq(submitted.origin.z, raw_transform.origin.z, 0.0001)

func test_landing_impact_offset_recovers_toward_zero_over_time() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_LandingRecoverTarget", Vector3.ZERO)
	await _create_vcam_component(ecs_manager, StringName("cam_landing_recover"), _new_orbit_mode(), follow_target)
	var camera_state: C_CameraStateComponent = _create_camera_state_component(
		ecs_manager,
		Vector3(0.0, -0.3, 0.0),
		8.0
	)

	vcam_manager.active_vcam_id = StringName("cam_landing_recover")
	var initial_y: float = camera_state.landing_impact_offset.y
	for _i in range(15):
		ecs_manager._physics_process(0.016)

	assert_true(camera_state.landing_impact_offset.y > initial_y)
	assert_true(camera_state.landing_impact_offset.y <= 0.0)

func test_landing_impact_recovery_is_critically_damped_without_positive_overshoot() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_LandingDampedTarget", Vector3.ZERO)
	await _create_vcam_component(ecs_manager, StringName("cam_landing_damped"), _new_orbit_mode(), follow_target)
	var camera_state: C_CameraStateComponent = _create_camera_state_component(
		ecs_manager,
		Vector3(0.0, -0.3, 0.0),
		8.0
	)

	vcam_manager.active_vcam_id = StringName("cam_landing_damped")
	var max_y: float = -INF
	for _i in range(180):
		ecs_manager._physics_process(0.016)
		max_y = maxf(max_y, camera_state.landing_impact_offset.y)

	assert_true(max_y <= 0.0001)
	assert_true(camera_state.landing_impact_offset.y > -0.01)

func test_zero_landing_impact_offset_adds_no_extra_position() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_LandingZeroTarget", Vector3.ZERO)
	var mode := _new_orbit_mode()
	var component := await _create_vcam_component(ecs_manager, StringName("cam_landing_zero"), mode, follow_target)
	_create_camera_state_component(ecs_manager, Vector3.ZERO, 8.0)

	vcam_manager.active_vcam_id = StringName("cam_landing_zero")
	ecs_manager._physics_process(0.016)

	var submitted: Transform3D = _extract_submission_transform(vcam_manager, StringName("cam_landing_zero"))
	var raw_result: Dictionary = _evaluate_raw_result(mode, follow_target, component)
	var raw_transform := raw_result.get("transform", Transform3D.IDENTITY) as Transform3D
	_assert_transform_close(submitted, raw_transform, 0.0001, 0.0001)

func test_active_vcam_fov_updates_primary_camera_state_base_fov() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_BaseFovTarget", Vector3.ZERO)
	var mode := _new_orbit_mode()
	mode.fov = 63.0
	await _create_vcam_component(ecs_manager, StringName("cam_base_fov_sync"), mode, follow_target)
	var camera_state: C_CameraStateComponent = _create_camera_state_component(
		ecs_manager,
		Vector3.ZERO,
		8.0
	)
	camera_state.base_fov = 0.0

	vcam_manager.active_vcam_id = StringName("cam_base_fov_sync")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(camera_state.base_fov, 63.0, 0.0001)

func test_active_vcam_fov_clamps_base_fov_to_supported_range() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_BaseFovClampTarget", Vector3.ZERO)
	var mode := _new_orbit_mode()
	mode.fov = 999.0
	await _create_vcam_component(ecs_manager, StringName("cam_base_fov_clamp"), mode, follow_target)
	var camera_state: C_CameraStateComponent = _create_camera_state_component(
		ecs_manager,
		Vector3.ZERO,
		8.0
	)
	camera_state.base_fov = 40.0

	vcam_manager.active_vcam_id = StringName("cam_base_fov_clamp")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(camera_state.base_fov, 179.0, 0.0001)

func test_missing_or_invalid_fov_result_does_not_change_base_fov() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var camera_state: C_CameraStateComponent = _create_camera_state_component(
		ecs_manager,
		Vector3.ZERO,
		8.0
	)
	camera_state.base_fov = 77.0

	system.call("_write_active_camera_base_fov_from_result", {})
	assert_almost_eq(camera_state.base_fov, 77.0, 0.0001)

	system.call("_write_active_camera_base_fov_from_result", {"fov": NAN})
	assert_almost_eq(camera_state.base_fov, 77.0, 0.0001)

	system.call("_write_active_camera_base_fov_from_result", {"fov": "bad"})
	assert_almost_eq(camera_state.base_fov, 77.0, 0.0001)

func test_rotation_continuity_orbit_to_first_person_carries_yaw_and_resets_pitch() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_ContinuityOrbitToFP", Vector3.ZERO)
	var orbit_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_out"),
		_new_orbit_mode(),
		follow_target
	)
	var first_person_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_fp_in"),
		_new_first_person_mode(),
		follow_target
	)
	orbit_component.runtime_yaw = 42.0
	orbit_component.runtime_pitch = -18.0
	first_person_component.runtime_yaw = -5.0
	first_person_component.runtime_pitch = 9.0

	vcam_manager.active_vcam_id = StringName("cam_orbit_out")
	ecs_manager._physics_process(0.016)
	vcam_manager.previous_vcam_id = StringName("cam_orbit_out")
	vcam_manager.active_vcam_id = StringName("cam_fp_in")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(first_person_component.runtime_yaw, 42.0, 0.0001)
	assert_almost_eq(first_person_component.runtime_pitch, -18.0, 0.0001)

func test_rotation_continuity_first_person_to_orbit_carries_yaw_and_carries_pitch() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_ContinuityFPToOrbit", Vector3.ZERO)
	var first_person_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_fp_out"),
		_new_first_person_mode(),
		follow_target
	)
	var orbit_in_mode := _new_orbit_mode()
	orbit_in_mode.authored_yaw = 35.0
	orbit_in_mode.authored_pitch = -22.0
	var orbit_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_in"),
		orbit_in_mode,
		follow_target
	)
	first_person_component.runtime_yaw = -27.5
	first_person_component.runtime_pitch = 13.0
	orbit_component.runtime_yaw = 100.0
	orbit_component.runtime_pitch = -55.0

	vcam_manager.active_vcam_id = StringName("cam_fp_out")
	ecs_manager._physics_process(0.016)
	vcam_manager.previous_vcam_id = StringName("cam_fp_out")
	vcam_manager.active_vcam_id = StringName("cam_orbit_in")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(orbit_component.runtime_yaw, -27.5, 0.0001)
	assert_almost_eq(orbit_component.runtime_pitch, 13.0, 0.0001)

func test_rotation_continuity_orbit_to_fixed_preserves_outgoing_rotation_state() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_ContinuityOrbitToFixed", Vector3.ZERO)
	var orbit_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_keep"),
		_new_orbit_mode(),
		follow_target
	)
	var fixed_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_fixed_in"),
		RS_VCAM_MODE_FIXED.new(),
		follow_target
	)
	orbit_component.runtime_yaw = 19.0
	orbit_component.runtime_pitch = -7.0
	fixed_component.runtime_yaw = 2.0
	fixed_component.runtime_pitch = 3.0

	vcam_manager.active_vcam_id = StringName("cam_orbit_keep")
	ecs_manager._physics_process(0.016)
	vcam_manager.previous_vcam_id = StringName("cam_orbit_keep")
	vcam_manager.active_vcam_id = StringName("cam_fixed_in")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(orbit_component.runtime_yaw, 19.0, 0.0001)
	assert_almost_eq(orbit_component.runtime_pitch, -7.0, 0.0001)

func test_rotation_continuity_fixed_to_orbit_reseeds_to_authored_yaw_and_zero_pitch() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_ContinuityFixedToOrbit", Vector3.ZERO)
	var fixed_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_fixed_out"),
		RS_VCAM_MODE_FIXED.new(),
		follow_target
	)
	var orbit_mode := _new_orbit_mode()
	orbit_mode.authored_yaw = 28.0
	orbit_mode.authored_pitch = -15.0
	var orbit_component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_reseed"),
		orbit_mode,
		follow_target
	)
	fixed_component.runtime_yaw = 80.0
	fixed_component.runtime_pitch = -40.0
	orbit_component.runtime_yaw = -11.0
	orbit_component.runtime_pitch = 6.0

	vcam_manager.active_vcam_id = StringName("cam_fixed_out")
	ecs_manager._physics_process(0.016)
	vcam_manager.previous_vcam_id = StringName("cam_fixed_out")
	vcam_manager.active_vcam_id = StringName("cam_orbit_reseed")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(orbit_component.runtime_yaw, 28.0, 0.0001)
	assert_almost_eq(orbit_component.runtime_pitch, 0.0, 0.0001)

func test_rotation_continuity_same_mode_same_target_carries_yaw_and_pitch() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var shared_target := _create_target_entity(ecs_manager, "E_ContinuitySharedTarget", Vector3.ZERO)
	var orbit_a := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_shared_a"),
		_new_orbit_mode(),
		shared_target
	)
	var orbit_b := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_shared_b"),
		_new_orbit_mode(),
		shared_target
	)
	orbit_a.runtime_yaw = 14.0
	orbit_a.runtime_pitch = -4.0
	orbit_b.runtime_yaw = 100.0
	orbit_b.runtime_pitch = 100.0

	vcam_manager.active_vcam_id = StringName("cam_orbit_shared_a")
	ecs_manager._physics_process(0.016)
	vcam_manager.previous_vcam_id = StringName("cam_orbit_shared_a")
	vcam_manager.active_vcam_id = StringName("cam_orbit_shared_b")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(orbit_b.runtime_yaw, 14.0, 0.0001)
	assert_almost_eq(orbit_b.runtime_pitch, -4.0, 0.0001)

func test_rotation_continuity_same_mode_different_target_reseeds_to_authored_angles() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var first_target := _create_target_entity(ecs_manager, "E_ContinuityTargetA", Vector3.ZERO)
	var second_target := _create_target_entity(ecs_manager, "E_ContinuityTargetB", Vector3(5.0, 0.0, 0.0))

	var orbit_out := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_target_a"),
		_new_orbit_mode(),
		first_target
	)
	var orbit_in_mode := _new_orbit_mode()
	orbit_in_mode.authored_yaw = 33.0
	orbit_in_mode.authored_pitch = -12.0
	var orbit_in := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_target_b"),
		orbit_in_mode,
		second_target
	)
	orbit_out.runtime_yaw = -70.0
	orbit_out.runtime_pitch = 25.0
	orbit_in.runtime_yaw = 2.0
	orbit_in.runtime_pitch = 3.0

	vcam_manager.active_vcam_id = StringName("cam_orbit_target_a")
	ecs_manager._physics_process(0.016)
	vcam_manager.previous_vcam_id = StringName("cam_orbit_target_a")
	vcam_manager.active_vcam_id = StringName("cam_orbit_target_b")
	ecs_manager._physics_process(0.016)

	assert_almost_eq(orbit_in.runtime_yaw, 33.0, 0.0001)
	assert_almost_eq(orbit_in.runtime_pitch, -12.0, 0.0001)

func test_does_nothing_when_no_active_vcam_exists() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

	var follow_target := _create_target_entity(ecs_manager, "E_NoActiveTarget", Vector3.ZERO)
	await _create_vcam_component(ecs_manager, StringName("cam_no_active"), _new_orbit_mode(), follow_target)

	vcam_manager.active_vcam_id = StringName("")
	ecs_manager._physics_process(0.016)

	assert_eq(vcam_manager.submit_calls, 0, "System should no-op when no active vcam is selected")

func test_does_nothing_when_vcam_manager_not_found() -> void:
	var context: Dictionary = await _setup_context(false)
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_MissingManagerTarget", Vector3.ZERO)
	await _create_vcam_component(ecs_manager, StringName("cam_missing_manager"), _new_orbit_mode(), follow_target)

	ecs_manager._physics_process(0.016)

	assert_eq(system.get("_vcam_manager"), null, "System should remain unresolved when manager service is unavailable")

func _setup_context(register_vcam_service: bool = true) -> Dictionary:
	var ecs_manager := M_ECS_MANAGER.new()
	add_child(ecs_manager)
	autofree(ecs_manager)
	await _pump()

	var store := MOCK_STATE_STORE.new()
	add_child(store)
	autofree(store)
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO, "camera_center_just_pressed": false})
	await _pump()

	U_ServiceLocator.register(StringName("state_store"), store)

	var vcam_manager := VCamManagerStub.new()
	add_child(vcam_manager)
	autofree(vcam_manager)
	if register_vcam_service:
		U_ServiceLocator.register(StringName("vcam_manager"), vcam_manager)

	var system := S_VCAM_SYSTEM.new()
	system.debug_rotation_logging = false
	ecs_manager.add_child(system)
	autofree(system)
	await _pump()
	await _pump()

	return {
		"ecs_manager": ecs_manager,
		"store": store,
		"vcam_manager": vcam_manager,
		"system": system,
	}

func _create_target_entity(
	ecs_manager: M_ECSManager,
	name: String,
	position: Vector3,
	entity_id: StringName = StringName(""),
	tags: Array[StringName] = []
) -> BaseECSEntity:
	var entity := BASE_ECS_ENTITY.new()
	entity.name = name
	entity.entity_id = entity_id
	entity.tags = tags.duplicate()
	ecs_manager.add_child(entity)
	autofree(entity)
	entity.global_position = position
	return entity

func _set_gameplay_entity_velocity(
	store: MockStateStore,
	entity: BaseECSEntity,
	velocity: Vector3,
	is_moving: bool = true
) -> void:
	if store == null or entity == null or not is_instance_valid(entity):
		return

	var gameplay_slice: Dictionary = store.get_slice(StringName("gameplay"))
	var entities_variant: Variant = gameplay_slice.get("entities", {})
	var entities: Dictionary = {}
	if entities_variant is Dictionary:
		entities = (entities_variant as Dictionary).duplicate(true)

	var entity_id: String = String(entity.get_entity_id())
	var entity_state_variant: Variant = entities.get(entity_id, {})
	var entity_state: Dictionary = {}
	if entity_state_variant is Dictionary:
		entity_state = (entity_state_variant as Dictionary).duplicate(true)

	entity_state["velocity"] = velocity
	entity_state["is_moving"] = is_moving
	entities[entity_id] = entity_state
	gameplay_slice["entities"] = entities

	if not gameplay_slice.has("player_entity_id"):
		gameplay_slice["player_entity_id"] = entity_id

	store.set_slice(StringName("gameplay"), gameplay_slice)

func _set_gameplay_entity_floor_state(
	store: MockStateStore,
	entity: BaseECSEntity,
	is_on_floor: bool
) -> void:
	if store == null or entity == null or not is_instance_valid(entity):
		return

	var gameplay_slice: Dictionary = store.get_slice(StringName("gameplay"))
	var entities_variant: Variant = gameplay_slice.get("entities", {})
	var entities: Dictionary = {}
	if entities_variant is Dictionary:
		entities = (entities_variant as Dictionary).duplicate(true)

	var entity_id: String = String(entity.get_entity_id())
	var entity_state_variant: Variant = entities.get(entity_id, {})
	var entity_state: Dictionary = {}
	if entity_state_variant is Dictionary:
		entity_state = (entity_state_variant as Dictionary).duplicate(true)

	entity_state["is_on_floor"] = is_on_floor
	entities[entity_id] = entity_state
	gameplay_slice["entities"] = entities
	if not gameplay_slice.has("player_entity_id"):
		gameplay_slice["player_entity_id"] = entity_id

	store.set_slice(StringName("gameplay"), gameplay_slice)

func _create_path_node(parent: Node3D, name: String) -> Path3D:
	var path := Path3D.new()
	path.name = name
	path.curve = Curve3D.new()
	path.curve.add_point(Vector3(0.0, 0.0, 0.0))
	path.curve.add_point(Vector3(0.0, 0.0, 5.0))
	parent.add_child(path)
	autofree(path)
	return path

func _create_box_obstacle(name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var obstacle := StaticBody3D.new()
	obstacle.name = name
	add_child(obstacle)
	autofree(obstacle)
	obstacle.global_position = position

	var collision_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision_shape.shape = box
	obstacle.add_child(collision_shape)
	autofree(collision_shape)
	return obstacle

func _publish_player_landing_event(fall_speed: float) -> void:
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_ENTITY_LANDED, {
		"entity_id": StringName("player"),
		"fall_speed": fall_speed,
	})

func _create_camera_state_component(
	ecs_manager: M_ECSManager,
	landing_impact_offset: Vector3,
	recovery_speed_hz: float
) -> C_CameraStateComponent:
	var camera_entity := BASE_ECS_ENTITY.new()
	camera_entity.name = "E_Camera"
	ecs_manager.add_child(camera_entity)
	autofree(camera_entity)

	var component := C_CAMERA_STATE_COMPONENT.new()
	component.landing_impact_offset = landing_impact_offset
	component.landing_impact_recovery_speed = recovery_speed_hz
	camera_entity.add_child(component)
	autofree(component)
	ecs_manager.register_component(component)

	return component

func _create_vcam_component(
	ecs_manager: M_ECSManager,
	vcam_id: StringName,
	mode: Resource,
	follow_target: Node3D = null
) -> C_VCamComponent:
	var camera_entity := BASE_ECS_ENTITY.new()
	camera_entity.name = "E_%sHost" % String(vcam_id)
	ecs_manager.add_child(camera_entity)
	autofree(camera_entity)

	var component := C_VCAM_COMPONENT.new()
	component.vcam_id = vcam_id
	component.mode = mode
	if follow_target != null and is_instance_valid(follow_target):
		component.follow_target_path = follow_target.get_path()
	camera_entity.add_child(component)
	autofree(component)

	await _pump()
	await _pump()
	return component

func _new_orbit_mode(allow_rotation: bool = true, rotation_speed: float = 1.0) -> Resource:
	var mode := RS_VCAM_MODE_ORBIT.new()
	mode.allow_player_rotation = allow_rotation
	mode.lock_x_rotation = false
	mode.lock_y_rotation = false
	mode.rotation_speed = rotation_speed
	mode.distance = 5.0
	mode.authored_pitch = -20.0
	mode.authored_yaw = 0.0
	return mode

func _new_first_person_mode(look_multiplier: float = 1.0) -> Resource:
	var mode := RS_VCAM_MODE_FIRST_PERSON.new()
	mode.look_multiplier = look_multiplier
	return mode

func _new_ots_mode(look_multiplier: float = 1.0) -> Resource:
	var mode := RS_VCAM_MODE_OTS.new()
	mode.look_multiplier = look_multiplier
	return mode

func _new_fixed_path_mode() -> Resource:
	var mode := RS_VCAM_MODE_FIXED.new()
	mode.use_path = true
	mode.use_world_anchor = true
	mode.track_target = false
	return mode

func _new_response(
	follow_frequency: float = 3.0,
	follow_damping: float = 0.7,
	follow_initial_response: float = 1.0,
	rotation_frequency: float = 4.0,
	rotation_damping: float = 1.0,
	rotation_initial_response: float = 1.0,
	look_ahead_distance: float = 0.0,
	look_ahead_smoothing: float = 3.0,
	auto_level_speed: float = 0.0,
	auto_level_delay: float = 1.0,
	look_input_deadzone: float = 0.02,
	look_input_hold_sec: float = 0.06,
	look_input_release_decay: float = 25.0,
	orbit_look_bypass_enable_speed: float = 0.15,
	orbit_look_bypass_disable_speed: float = 0.3,
	ground_relative_enabled: bool = false,
	ground_reanchor_min_height_delta: float = 0.5,
	ground_probe_max_distance: float = 12.0,
	ground_anchor_blend_hz: float = 4.0
) -> Resource:
	var response := RS_VCAM_RESPONSE.new()
	response.follow_frequency = follow_frequency
	response.follow_damping = follow_damping
	response.follow_initial_response = follow_initial_response
	response.rotation_frequency = rotation_frequency
	response.rotation_damping = rotation_damping
	response.rotation_initial_response = rotation_initial_response
	response.look_ahead_distance = look_ahead_distance
	response.look_ahead_smoothing = look_ahead_smoothing
	response.auto_level_speed = auto_level_speed
	response.auto_level_delay = auto_level_delay
	response.look_input_deadzone = look_input_deadzone
	response.look_input_hold_sec = look_input_hold_sec
	response.look_input_release_decay = look_input_release_decay
	response.orbit_look_bypass_enable_speed = orbit_look_bypass_enable_speed
	response.orbit_look_bypass_disable_speed = orbit_look_bypass_disable_speed
	response.ground_relative_enabled = ground_relative_enabled
	response.ground_reanchor_min_height_delta = ground_reanchor_min_height_delta
	response.ground_probe_max_distance = ground_probe_max_distance
	response.ground_anchor_blend_hz = ground_anchor_blend_hz
	return response

func _new_soft_zone(
	dead_zone_width: float = 0.1,
	dead_zone_height: float = 0.1,
	soft_zone_width: float = 0.4,
	soft_zone_height: float = 0.4,
	damping: float = 2.0,
	hysteresis_margin: float = 0.02
) -> Resource:
	var soft_zone := RS_VCAM_SOFT_ZONE.new()
	soft_zone.dead_zone_width = dead_zone_width
	soft_zone.dead_zone_height = dead_zone_height
	soft_zone.soft_zone_width = soft_zone_width
	soft_zone.soft_zone_height = soft_zone_height
	soft_zone.damping = damping
	soft_zone.hysteresis_margin = hysteresis_margin
	return soft_zone

func _create_projection_camera() -> Camera3D:
	var camera := Camera3D.new()
	add_child(camera)
	autofree(camera)
	camera.current = true
	return camera

func _evaluate_raw_result(mode: Resource, follow_target: Node3D, component: C_VCamComponent) -> Dictionary:
	return U_VCAM_MODE_EVALUATOR.evaluate(
		mode,
		follow_target,
		component.get_look_at_target(),
		component.runtime_yaw,
		component.runtime_pitch
	)

func _extract_submission_transform(vcam_manager: VCamManagerStub, vcam_id: StringName) -> Transform3D:
	var result: Dictionary = vcam_manager.get_submission(vcam_id)
	var transform_variant: Variant = result.get("transform", Transform3D.IDENTITY)
	return transform_variant as Transform3D

func _extract_roll_degrees(transform: Transform3D) -> float:
	return rad_to_deg(transform.basis.get_euler().z)

func _rotation_error(lhs: Transform3D, rhs: Transform3D) -> float:
	return lhs.basis.get_rotation_quaternion().angle_to(rhs.basis.get_rotation_quaternion())

func _assert_transform_close(lhs: Transform3D, rhs: Transform3D, origin_tolerance: float, basis_tolerance: float) -> void:
	assert_true(lhs.origin.distance_to(rhs.origin) <= origin_tolerance)
	assert_true(lhs.basis.x.distance_to(rhs.basis.x) <= basis_tolerance)
	assert_true(lhs.basis.y.distance_to(rhs.basis.y) <= basis_tolerance)
	assert_true(lhs.basis.z.distance_to(rhs.basis.z) <= basis_tolerance)

func test_orbit_position_smoothing_bypass_ignores_vertical_velocity() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_OrbitVerticalBypassTarget", Vector3.ZERO)
	var mode := _new_orbit_mode(true, 1.0)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_vertical_bypass"),
		mode,
		follow_target
	)
	component.response = _new_response(
		1.0, 0.7, 1.0,
		4.0, 1.0, 1.0,
		0.0, 3.0,
		0.0, 1.0,
		0.01, 0.0, 25.0,
		0.15, 0.3
	)

	vcam_manager.active_vcam_id = StringName("cam_orbit_vertical_bypass")
	store.set_slice(StringName("input"), {"look_input": Vector2(1.0, 0.0)})
	ecs_manager._physics_process(0.016)

	# Move target purely vertically (simulating a jump) — large Y displacement
	follow_target.global_position = Vector3(0.0, 2.0, 0.0)
	ecs_manager._physics_process(0.016)

	var bypass_state_all: Dictionary = system.get("_debug_position_smoothing_bypass_by_vcam") as Dictionary
	assert_true(
		bool(bypass_state_all.get(StringName("cam_orbit_vertical_bypass"), false)),
		"Pure vertical movement (jumping) should NOT disable orbit position smoothing bypass"
	)

func test_orbit_position_smoothing_bypass_still_disables_for_horizontal_movement() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_OrbitHorizBypassTarget", Vector3.ZERO)
	var mode := _new_orbit_mode(true, 1.0)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_horiz_bypass"),
		mode,
		follow_target
	)
	component.response = _new_response(
		1.0, 0.7, 1.0,
		4.0, 1.0, 1.0,
		0.0, 3.0,
		0.0, 1.0,
		0.01, 0.0, 25.0,
		0.15, 0.3
	)

	vcam_manager.active_vcam_id = StringName("cam_orbit_horiz_bypass")
	store.set_slice(StringName("input"), {"look_input": Vector2(1.0, 0.0)})
	ecs_manager._physics_process(0.016)

	# Move target horizontally at high speed — should still disable bypass
	follow_target.global_position = Vector3(2.0, 0.0, 0.0)
	ecs_manager._physics_process(0.016)

	var bypass_state_all: Dictionary = system.get("_debug_position_smoothing_bypass_by_vcam") as Dictionary
	assert_false(
		bool(bypass_state_all.get(StringName("cam_orbit_horiz_bypass"), true)),
		"Horizontal movement should still disable orbit position smoothing bypass"
	)

func test_orbit_position_smoothing_bypass_ignores_vertical_component_of_mixed_movement() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var store: MockStateStore = context["store"] as MockStateStore
	var system: S_VCamSystem = context["system"] as S_VCamSystem

	var follow_target := _create_target_entity(ecs_manager, "E_OrbitMixedBypassTarget", Vector3.ZERO)
	var mode := _new_orbit_mode(true, 1.0)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_orbit_mixed_bypass"),
		mode,
		follow_target
	)
	component.response = _new_response(
		1.0, 0.7, 1.0,
		4.0, 1.0, 1.0,
		0.0, 3.0,
		0.0, 1.0,
		0.01, 0.0, 25.0,
		0.15, 0.3
	)

	vcam_manager.active_vcam_id = StringName("cam_orbit_mixed_bypass")
	store.set_slice(StringName("input"), {"look_input": Vector2(1.0, 0.0)})
	ecs_manager._physics_process(0.016)

	# Small horizontal + large vertical — horizontal speed alone is below threshold
	follow_target.global_position = Vector3(0.001, 5.0, 0.001)
	ecs_manager._physics_process(0.016)

	var bypass_state_all: Dictionary = system.get("_debug_position_smoothing_bypass_by_vcam") as Dictionary
	assert_true(
		bool(bypass_state_all.get(StringName("cam_orbit_mixed_bypass"), false)),
		"Small horizontal + large vertical should keep bypass enabled (only horizontal counts)"
	)

func _expected_orbit_position(target_position: Vector3) -> Vector3:
	var distance: float = 5.0
	var pitch_rad: float = deg_to_rad(-20.0)
	var yaw_rad: float = deg_to_rad(0.0)
	var offset := Vector3(
		distance * cos(pitch_rad) * sin(yaw_rad),
		-distance * sin(pitch_rad),
		distance * cos(pitch_rad) * cos(yaw_rad)
	)
	return target_position + offset

func _pump() -> void:
	await get_tree().process_frame
