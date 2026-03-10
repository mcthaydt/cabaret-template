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
const RS_VCAM_MODE_FIXED := preload("res://scripts/resources/display/vcam/rs_vcam_mode_fixed.gd")
const RS_VCAM_RESPONSE := preload("res://scripts/resources/display/vcam/rs_vcam_response.gd")
const RS_VCAM_SOFT_ZONE := preload("res://scripts/resources/display/vcam/rs_vcam_soft_zone.gd")
const U_VCAM_MODE_EVALUATOR := preload("res://scripts/managers/helpers/u_vcam_mode_evaluator.gd")

class VCamManagerStub extends I_VCamManager:
	var active_vcam_id: StringName = StringName("")
	var previous_vcam_id: StringName = StringName("")
	var blending: bool = false
	var submit_calls: int = 0
	var submissions: Dictionary = {}

	func register_vcam(_vcam: Node) -> void:
		pass

	func unregister_vcam(_vcam: Node) -> void:
		pass

	func set_active_vcam(vcam_id: StringName, _blend_duration: float = -1.0) -> void:
		active_vcam_id = vcam_id

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

	follow_target.global_position = Vector3(5.0, 0.0, 0.0)
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

func test_orbit_look_ahead_offset_magnitude_is_clamped_to_distance() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub

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

	follow_target.global_position = Vector3(100.0, 0.0, 0.0)
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

	var follow_target := _create_target_entity(ecs_manager, "E_LookAheadStationaryTarget", Vector3.ZERO)
	var component := await _create_vcam_component(
		ecs_manager,
		StringName("cam_look_ahead_stationary"),
		_new_orbit_mode(),
		follow_target
	)
	component.response = _new_response(1000.0, 1.0, 1.0, 4.0, 1.0, 1.0, 2.0, 0.0)

	vcam_manager.active_vcam_id = StringName("cam_look_ahead_stationary")
	ecs_manager._physics_process(0.016)
	ecs_manager._physics_process(0.016)

	var look_ahead_state: Dictionary = system.get("_look_ahead_state") as Dictionary
	var state := look_ahead_state.get(StringName("cam_look_ahead_stationary"), {}) as Dictionary
	var offset := state.get("current_offset", Vector3.ONE) as Vector3
	assert_true(offset.is_zero_approx())

func test_orbit_look_ahead_clears_state_on_mode_switch() -> void:
	var context: Dictionary = await _setup_context()
	autofree_context(context)
	var ecs_manager: M_ECSManager = context["ecs_manager"] as M_ECSManager
	var vcam_manager: VCamManagerStub = context["vcam_manager"] as VCamManagerStub
	var system: S_VCamSystem = context["system"] as S_VCamSystem

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
	follow_target.global_position = Vector3(5.0, 0.0, 0.0)
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
	first_target.global_position = Vector3(6.0, 0.0, 0.0)
	ecs_manager._physics_process(0.016)

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
	assert_almost_eq(first_person_component.runtime_pitch, 0.0, 0.0001)

func test_rotation_continuity_first_person_to_orbit_carries_yaw_and_resets_pitch() -> void:
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
	assert_almost_eq(orbit_component.runtime_pitch, 0.0, 0.0001)

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
	store.set_slice(StringName("input"), {"look_input": Vector2.ZERO})
	await _pump()

	U_ServiceLocator.register(StringName("state_store"), store)

	var vcam_manager := VCamManagerStub.new()
	add_child(vcam_manager)
	autofree(vcam_manager)
	if register_vcam_service:
		U_ServiceLocator.register(StringName("vcam_manager"), vcam_manager)

	var system := S_VCAM_SYSTEM.new()
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

func _create_path_node(parent: Node3D, name: String) -> Path3D:
	var path := Path3D.new()
	path.name = name
	path.curve = Curve3D.new()
	path.curve.add_point(Vector3(0.0, 0.0, 0.0))
	path.curve.add_point(Vector3(0.0, 0.0, 5.0))
	parent.add_child(path)
	autofree(path)
	return path

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
	auto_level_delay: float = 1.0
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
		component.runtime_pitch,
		component.get_fixed_anchor()
	)

func _extract_submission_transform(vcam_manager: VCamManagerStub, vcam_id: StringName) -> Transform3D:
	var result: Dictionary = vcam_manager.get_submission(vcam_id)
	var transform_variant: Variant = result.get("transform", Transform3D.IDENTITY)
	return transform_variant as Transform3D

func _rotation_error(lhs: Transform3D, rhs: Transform3D) -> float:
	return lhs.basis.get_rotation_quaternion().angle_to(rhs.basis.get_rotation_quaternion())

func _assert_transform_close(lhs: Transform3D, rhs: Transform3D, origin_tolerance: float, basis_tolerance: float) -> void:
	assert_true(lhs.origin.distance_to(rhs.origin) <= origin_tolerance)
	assert_true(lhs.basis.x.distance_to(rhs.basis.x) <= basis_tolerance)
	assert_true(lhs.basis.y.distance_to(rhs.basis.y) <= basis_tolerance)
	assert_true(lhs.basis.z.distance_to(rhs.basis.z) <= basis_tolerance)

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
