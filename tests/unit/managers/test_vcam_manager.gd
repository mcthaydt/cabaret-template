extends BaseTest

const M_VCAM_MANAGER := preload("res://scripts/core/managers/m_vcam_manager.gd")
const I_VCAM_MANAGER := preload("res://scripts/core/interfaces/i_vcam_manager.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const RS_VCAM_MODE_ORBIT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const RS_VCAM_BLEND_HINT := preload("res://scripts/resources/display/vcam/rs_vcam_blend_hint.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_VCAM_ACTIONS := preload("res://scripts/state/actions/u_vcam_actions.gd")

class VCamManagerOcclusionStub extends M_VCAM_MANAGER:
	var test_follow_target: Node3D = null
	var test_occluders: Array = []

	func _resolve_follow_target_for_vcam(_vcam: Node) -> Node3D:
		if test_follow_target != null and is_instance_valid(test_follow_target):
			return test_follow_target
		return null

	func _detect_occluders_for_silhouette(
		_camera_transform: Transform3D,
		_follow_target: Node3D,
		_debug_enabled: bool = false,
		_debug_context: String = ""
	) -> Array:
		return test_occluders.duplicate(false)

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()

func test_manager_extends_interface() -> void:
	var manager := M_VCAM_MANAGER.new()
	autofree(manager)
	assert_true(manager is I_VCAM_MANAGER, "M_VCamManager should extend I_VCamManager")

func test_manager_registers_with_service_locator() -> void:
	var manager := await _create_manager()
	var service := U_SERVICE_LOCATOR.try_get_service(StringName("vcam_manager"))
	assert_eq(service, manager, "vcam_manager service should resolve to manager instance")

func test_register_vcam_adds_component_to_registry() -> void:
	var manager := await _create_manager()
	var camera_a := _create_vcam(StringName("cam_a"), 5)

	manager.register_vcam(camera_a)

	var by_id := manager.get("_vcams_by_id") as Dictionary
	assert_true(by_id.has(StringName("cam_a")), "Registry should include registered vcam id")
	assert_eq(by_id.get(StringName("cam_a"), null), camera_a, "Registry should map id to component")

func test_register_vcam_duplicate_id_is_rejected() -> void:
	var manager := await _create_manager()
	var camera_a := _create_vcam(StringName("cam_dup"), 5)
	var camera_b := _create_vcam(StringName("cam_dup"), 10)

	manager.register_vcam(camera_a)
	manager.register_vcam(camera_b)

	var by_id := manager.get("_vcams_by_id") as Dictionary
	assert_eq(by_id.size(), 1, "Duplicate vcam_id should not register twice")
	assert_eq(by_id.get(StringName("cam_dup"), null), camera_a, "Original component should remain registered")

func test_unregister_vcam_removes_component_from_registry() -> void:
	var manager := await _create_manager()
	var camera_a := _create_vcam(StringName("cam_a"), 5)
	manager.register_vcam(camera_a)

	manager.unregister_vcam(camera_a)

	var by_id := manager.get("_vcams_by_id") as Dictionary
	assert_false(by_id.has(StringName("cam_a")), "Registry should not include unregistered vcam")

func test_unregister_unknown_component_is_noop() -> void:
	var manager := await _create_manager()
	var camera_a := _create_vcam(StringName("cam_a"), 5)
	var unknown_camera := _create_vcam(StringName("cam_unknown"), 1)
	manager.register_vcam(camera_a)

	manager.unregister_vcam(unknown_camera)

	var by_id := manager.get("_vcams_by_id") as Dictionary
	assert_eq(by_id.size(), 1, "Unknown unregistration should not modify registry")
	assert_eq(manager.get_active_vcam_id(), StringName("cam_a"), "Active id should remain unchanged")

func test_unregistering_active_vcam_clears_active_state() -> void:
	var manager := await _create_manager()
	var camera_a := _create_vcam(StringName("cam_a"), 5)
	manager.register_vcam(camera_a)
	assert_eq(manager.get_active_vcam_id(), StringName("cam_a"))

	manager.unregister_vcam(camera_a)

	assert_eq(manager.get_active_vcam_id(), StringName(""), "Active id should clear when active vcam unregisters")

func test_unregistering_active_vcam_with_replacement_publishes_previous_active_id() -> void:
	var store := MOCK_STATE_STORE.new()
	add_child(store)
	autofree(store)
	var manager := await _create_manager(store)
	var camera_high := _create_vcam(StringName("cam_high"), 10)
	var camera_low := _create_vcam(StringName("cam_low"), 1)
	manager.register_vcam(camera_high)
	manager.register_vcam(camera_low)
	assert_eq(manager.get_active_vcam_id(), StringName("cam_high"))
	store.clear_dispatched_actions()

	manager.unregister_vcam(camera_high)

	assert_eq(manager.get_active_vcam_id(), StringName("cam_low"))
	var action: Dictionary = _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_SET_ACTIVE_RUNTIME
	)
	assert_false(action.is_empty(), "Unregister reselection should dispatch set_active_runtime action")
	var payload := action.get("payload", {}) as Dictionary
	assert_eq(payload.get("vcam_id", StringName("")), StringName("cam_low"))

func test_unregistering_last_active_vcam_publishes_clear_event_and_runtime_clear_action() -> void:
	var store := MOCK_STATE_STORE.new()
	add_child(store)
	autofree(store)
	var manager := await _create_manager(store)
	var camera_a := _create_vcam(StringName("cam_a"), 5)
	manager.register_vcam(camera_a)
	store.clear_dispatched_actions()

	manager.unregister_vcam(camera_a)

	assert_eq(manager.get_active_vcam_id(), StringName(""), "Active id should clear when last vcam unregisters")
	var action: Dictionary = _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_SET_ACTIVE_RUNTIME
	)
	assert_false(action.is_empty(), "Unregistering last active vcam should dispatch set_active_runtime action")
	var payload := action.get("payload", {}) as Dictionary
	assert_eq(payload.get("vcam_id", StringName("")), StringName(""))
	assert_eq(str(payload.get("mode", "__missing__")), "")

func test_unregistering_all_vcams_clears_all_state() -> void:
	var manager := await _create_manager()
	var camera_a := _create_vcam(StringName("cam_a"), 5)
	var camera_b := _create_vcam(StringName("cam_b"), 3)
	manager.register_vcam(camera_a)
	manager.register_vcam(camera_b)
	manager.submit_evaluated_camera(StringName("cam_a"), {"mode_name": "orbit"})

	manager.unregister_vcam(camera_a)
	manager.unregister_vcam(camera_b)

	var by_id := manager.get("_vcams_by_id") as Dictionary
	var by_component := manager.get("_registered_vcams") as Dictionary
	var submitted := manager.get("_submitted_results") as Dictionary
	assert_eq(by_id.size(), 0, "All vcams should be removed from id registry")
	assert_eq(by_component.size(), 0, "All vcams should be removed from component registry")
	assert_eq(submitted.size(), 0, "Submitted results should be cleared when no vcams remain")
	assert_eq(manager.get_active_vcam_id(), StringName(""), "Active id should reset")
	assert_eq(manager.get_previous_vcam_id(), StringName(""), "Previous id should reset")

func test_set_active_vcam_by_explicit_id_sets_active_vcam() -> void:
	var manager := await _create_manager()
	var camera_a := _create_vcam(StringName("cam_a"), 1)
	var camera_b := _create_vcam(StringName("cam_b"), 5)
	manager.register_vcam(camera_a)
	manager.register_vcam(camera_b)

	manager.set_active_vcam(StringName("cam_a"))

	assert_eq(manager.get_active_vcam_id(), StringName("cam_a"), "Explicit active id should override priority selection")

func test_set_active_vcam_unknown_id_does_nothing() -> void:
	var manager := await _create_manager()
	var camera_a := _create_vcam(StringName("cam_a"), 1)
	manager.register_vcam(camera_a)
	var before := manager.get_active_vcam_id()

	manager.set_active_vcam(StringName("missing_camera"))

	assert_eq(manager.get_active_vcam_id(), before, "Unknown active id should not change current active camera")

func test_priority_selection_chooses_highest_priority() -> void:
	var manager := await _create_manager()
	manager.register_vcam(_create_vcam(StringName("cam_low"), 1))
	manager.register_vcam(_create_vcam(StringName("cam_high"), 10))

	assert_eq(manager.get_active_vcam_id(), StringName("cam_high"), "Highest priority active vcam should win")

func test_priority_tie_break_uses_ascending_vcam_id() -> void:
	var manager := await _create_manager()
	manager.register_vcam(_create_vcam(StringName("cam_b"), 4))
	manager.register_vcam(_create_vcam(StringName("cam_a"), 4))

	assert_eq(manager.get_active_vcam_id(), StringName("cam_a"), "Tie-break should choose lexicographically smallest vcam_id")

func test_get_active_vcam_id_returns_current_active() -> void:
	var manager := await _create_manager()
	manager.register_vcam(_create_vcam(StringName("cam_main"), 2))

	assert_eq(manager.get_active_vcam_id(), StringName("cam_main"))

func test_get_active_vcam_id_returns_empty_when_none_registered() -> void:
	var manager := await _create_manager()
	assert_eq(manager.get_active_vcam_id(), StringName(""))

func test_set_active_vcam_dispatches_runtime_action() -> void:
	var store := MOCK_STATE_STORE.new()
	add_child(store)
	autofree(store)

	var manager := await _create_manager(store)
	manager.register_vcam(_create_vcam(StringName("cam_a"), 1))
	manager.register_vcam(_create_vcam(StringName("cam_b"), 5))
	store.clear_dispatched_actions()

	manager.set_active_vcam(StringName("cam_a"))

	var actions := store.get_dispatched_actions()
	assert_true(actions.size() > 0, "Active switch should dispatch runtime action")
	var last_action: Dictionary = actions[actions.size() - 1]
	assert_eq(last_action.get("type", StringName("")), U_VCAM_ACTIONS.ACTION_SET_ACTIVE_RUNTIME)
	var payload := last_action.get("payload", {}) as Dictionary
	assert_eq(payload.get("vcam_id", StringName("")), StringName("cam_a"))

func test_set_active_vcam_publishes_active_changed_event() -> void:
	var store := MOCK_STATE_STORE.new()
	add_child(store)
	autofree(store)
	var manager := await _create_manager(store)
	manager.register_vcam(_create_vcam(StringName("cam_a"), 1))
	manager.register_vcam(_create_vcam(StringName("cam_b"), 5))
	store.clear_dispatched_actions()

	manager.set_active_vcam(StringName("cam_a"))

	var action: Dictionary = _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_SET_ACTIVE_RUNTIME
	)
	assert_false(action.is_empty(), "Active switch should dispatch set_active_runtime action")
	var payload := action.get("payload", {}) as Dictionary
	assert_eq(payload.get("vcam_id", StringName("")), StringName("cam_a"))
	assert_eq(payload.get("mode", ""), "orbit")

func test_inactive_vcams_are_excluded_from_priority_selection() -> void:
	var manager := await _create_manager()
	manager.register_vcam(_create_vcam(StringName("cam_active"), 1, true))
	manager.register_vcam(_create_vcam(StringName("cam_inactive"), 99, false))

	assert_eq(manager.get_active_vcam_id(), StringName("cam_active"), "Inactive vcam should not win selection")

func test_active_vcam_becoming_inactive_triggers_reselection() -> void:
	var manager := await _create_manager()
	var camera_low := _create_vcam(StringName("cam_low"), 1, true)
	var camera_high := _create_vcam(StringName("cam_high"), 5, true)
	manager.register_vcam(camera_low)
	manager.register_vcam(camera_high)
	assert_eq(manager.get_active_vcam_id(), StringName("cam_high"))

	camera_high.is_active = false
	manager._physics_process(0.016)

	assert_eq(manager.get_active_vcam_id(), StringName("cam_low"), "Selection should reseat when active vcam is disabled")

func test_priority_reselection_after_unregister_picks_next_highest() -> void:
	var manager := await _create_manager()
	var camera_low := _create_vcam(StringName("cam_low"), 1, true)
	var camera_high := _create_vcam(StringName("cam_high"), 8, true)
	manager.register_vcam(camera_low)
	manager.register_vcam(camera_high)
	assert_eq(manager.get_active_vcam_id(), StringName("cam_high"))

	manager.unregister_vcam(camera_high)

	assert_eq(manager.get_active_vcam_id(), StringName("cam_low"), "Next-highest priority camera should become active")

func test_pruned_invalid_active_vcam_publishes_previous_active_id() -> void:
	var store := MOCK_STATE_STORE.new()
	add_child(store)
	autofree(store)
	var manager := await _create_manager(store)
	var camera_low := _create_vcam(StringName("cam_low"), 1, true)
	var camera_high := _create_vcam(StringName("cam_high"), 8, true)
	manager.register_vcam(camera_low)
	manager.register_vcam(camera_high)
	assert_eq(manager.get_active_vcam_id(), StringName("cam_high"))
	store.clear_dispatched_actions()

	camera_high.queue_free()
	await get_tree().process_frame
	manager._physics_process(0.016)

	assert_eq(manager.get_active_vcam_id(), StringName("cam_low"))
	var action: Dictionary = _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_SET_ACTIVE_RUNTIME
	)
	assert_false(action.is_empty(), "Pruned active vcam should dispatch set_active_runtime action")
	var payload := action.get("payload", {}) as Dictionary
	assert_eq(payload.get("vcam_id", StringName("")), StringName("cam_low"))

func test_submit_evaluated_camera_applies_active_transform_to_camera_manager() -> void:
	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)

	var manager := await _create_manager(null, camera_manager)
	var camera_a := _create_vcam(StringName("cam_a"), 5)
	manager.register_vcam(camera_a)

	var expected := Transform3D(Basis.IDENTITY, Vector3(1.25, 2.5, -3.75))
	manager.submit_evaluated_camera(StringName("cam_a"), {"transform": expected})

	assert_eq(camera_manager.apply_main_transform_calls, 1, "Active submission should be applied to camera manager")
	assert_eq(camera_manager.last_main_transform, expected, "Applied camera transform should match submission")

func test_submit_evaluated_camera_does_not_apply_for_inactive_vcam() -> void:
	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)

	var manager := await _create_manager(null, camera_manager)
	manager.register_vcam(_create_vcam(StringName("cam_a"), 5))
	manager.register_vcam(_create_vcam(StringName("cam_b"), 1))

	manager.submit_evaluated_camera(
		StringName("cam_b"),
		{"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 2.0))}
	)

	assert_eq(camera_manager.apply_main_transform_calls, 0, "Non-active submissions must not drive main camera")

func test_submit_evaluated_camera_respects_camera_blend_gate() -> void:
	var camera_manager := MOCK_CAMERA_MANAGER.new()
	camera_manager.blend_active = true
	add_child(camera_manager)
	autofree(camera_manager)

	var manager := await _create_manager(null, camera_manager)
	manager.register_vcam(_create_vcam(StringName("cam_a"), 5))

	manager.submit_evaluated_camera(
		StringName("cam_a"),
		{"transform": Transform3D(Basis.IDENTITY, Vector3(4.0, 5.0, 6.0))}
	)

	assert_eq(camera_manager.apply_main_transform_calls, 0, "Blend-active camera manager should ignore gameplay apply")

func test_submit_evaluated_camera_startup_blend_lerps_from_main_camera_transform() -> void:
	var camera_manager := MOCK_CAMERA_MANAGER.new()
	var main_camera := Camera3D.new()
	main_camera.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	camera_manager.main_camera = main_camera
	add_child(camera_manager)
	add_child(main_camera)
	autofree(camera_manager)
	autofree(main_camera)

	var manager := await _create_manager(null, camera_manager)
	var startup_blend := RS_VCAM_BLEND_HINT.new()
	startup_blend.blend_duration = 0.5
	startup_blend.trans_type = Tween.TRANS_LINEAR
	startup_blend.ease_type = Tween.EASE_IN_OUT
	var camera_a := _create_vcam(StringName("cam_a"), 5, true, startup_blend)
	manager.register_vcam(camera_a)
	manager._physics_process(0.1)

	var target := Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0))
	manager.submit_evaluated_camera(StringName("cam_a"), {"transform": target})

	assert_eq(camera_manager.apply_main_transform_calls, 1, "Startup blend should still apply camera transform")
	assert_true(
		camera_manager.last_main_transform.origin.x > 0.0 and camera_manager.last_main_transform.origin.x < 10.0,
		"Startup blend should interpolate between current and target positions"
	)

func test_submit_evaluated_camera_startup_blend_can_cut_on_distance_threshold() -> void:
	var camera_manager := MOCK_CAMERA_MANAGER.new()
	var main_camera := Camera3D.new()
	main_camera.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	camera_manager.main_camera = main_camera
	add_child(camera_manager)
	add_child(main_camera)
	autofree(camera_manager)
	autofree(main_camera)

	var manager := await _create_manager(null, camera_manager)
	var startup_blend := RS_VCAM_BLEND_HINT.new()
	startup_blend.blend_duration = 1.0
	startup_blend.cut_on_distance_threshold = 0.5
	var camera_a := _create_vcam(StringName("cam_a"), 5, true, startup_blend)
	manager.register_vcam(camera_a)
	manager._physics_process(0.1)

	var target := Transform3D(Basis.IDENTITY, Vector3(3.0, 0.0, 0.0))
	manager.submit_evaluated_camera(StringName("cam_a"), {"transform": target})

	assert_eq(
		camera_manager.last_main_transform,
		target,
		"Large startup offset should instant-cut when cut threshold is exceeded"
	)

func test_submit_evaluated_camera_publishes_silhouette_update_request_event() -> void:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("gameplay"), {
		"player_entity_id": "player",
	})
	add_child(store)
	autofree(store)

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)

	var manager := await _create_manager(store, camera_manager)
	var camera_a := _create_vcam(StringName("cam_a"), 5)
	var follow_target := Node3D.new()
	camera_a.add_child(follow_target)
	autofree(follow_target)
	await get_tree().process_frame
	camera_a.follow_target_path = camera_a.get_path_to(follow_target)

	store.clear_dispatched_actions()
	manager.submit_evaluated_camera(
		StringName("cam_a"),
		{"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 4.0))}
	)

	var action: Dictionary = _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_SILHOUETTE_UPDATE_REQUEST
	)
	assert_false(action.is_empty(), "Submitting active camera should dispatch silhouette update request action")
	assert_eq(action.get("entity_id", StringName("")), StringName("player"))
	assert_true(action.get("occluders", []) is Array)
	assert_eq(action.get("enabled", false), true)

func test_submit_evaluated_camera_includes_detected_occluders_when_silhouette_enabled() -> void:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("gameplay"), {"player_entity_id": "player"})
	store.set_slice(StringName("vfx"), {"occlusion_silhouette_enabled": true})
	add_child(store)
	autofree(store)

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)

	var manager := await _create_occlusion_test_manager(store, camera_manager)
	var camera_a := _create_vcam(StringName("cam_a"), 5)
	manager.register_vcam(camera_a)
	var follow_target := Node3D.new()
	add_child(follow_target)
	autofree(follow_target)
	manager.test_follow_target = follow_target
	var occluder_a := _create_mesh_occluder()
	var occluder_b := _create_mesh_occluder()
	manager.test_occluders = [occluder_a, occluder_b]

	store.clear_dispatched_actions()
	manager.submit_evaluated_camera(StringName("cam_a"), {"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 1.0))})

	var action := _find_last_silhouette_payload(store)
	assert_false(action.is_empty(), "Silhouette action should be dispatched when toggle is enabled")
	assert_eq(action.get("enabled", false), true, "Silhouette request should remain enabled")
	var occluders := action.get("occluders", []) as Array
	assert_eq(occluders.size(), 2, "Detected occluders should be forwarded in payload")

func test_submit_evaluated_camera_disables_silhouette_when_vfx_toggle_is_off() -> void:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("gameplay"), {"player_entity_id": "player"})
	store.set_slice(StringName("vfx"), {"occlusion_silhouette_enabled": false})
	add_child(store)
	autofree(store)

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)

	var manager := await _create_occlusion_test_manager(store, camera_manager)
	manager.register_vcam(_create_vcam(StringName("cam_a"), 5))
	var follow_target := Node3D.new()
	add_child(follow_target)
	autofree(follow_target)
	manager.test_follow_target = follow_target
	manager.test_occluders = [_create_mesh_occluder()]

	store.clear_dispatched_actions()
	manager.submit_evaluated_camera(StringName("cam_a"), {"transform": Transform3D.IDENTITY})

	var action := _find_last_silhouette_payload(store)
	assert_false(action.is_empty(), "Silhouette disable action should be dispatched when toggle is off")
	assert_eq(action.get("enabled", true), false, "Silhouette request should disable rendering when toggle is off")
	var occluders := action.get("occluders", []) as Array
	assert_eq(occluders.size(), 0, "Disabled request should not carry occluders")

func test_submit_evaluated_camera_does_not_dispatch_silhouette_count_action() -> void:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("gameplay"), {"player_entity_id": "player"})
	store.set_slice(StringName("vfx"), {"occlusion_silhouette_enabled": true})
	add_child(store)
	autofree(store)

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)

	var manager := await _create_occlusion_test_manager(store, camera_manager)
	manager.register_vcam(_create_vcam(StringName("cam_a"), 5))
	var follow_target := Node3D.new()
	add_child(follow_target)
	autofree(follow_target)
	manager.test_follow_target = follow_target
	var occluder := _create_mesh_occluder()

	manager.test_occluders = [occluder]
	manager.submit_evaluated_camera(StringName("cam_a"), {"transform": Transform3D.IDENTITY})
	assert_true(
		_find_last_action_by_type(
			store.get_dispatched_actions(),
			U_VCAM_ACTIONS.ACTION_UPDATE_SILHOUETTE_COUNT
		).is_empty(),
		"Silhouette count dispatch is owned by M_VFXManager after debounce/grace filtering"
	)

func test_unregistering_active_vcam_publishes_silhouette_clear_request() -> void:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("gameplay"), {"player_entity_id": "player"})
	store.set_slice(StringName("vfx"), {"occlusion_silhouette_enabled": true})
	add_child(store)
	autofree(store)

	var manager := await _create_occlusion_test_manager(store)
	var camera_a := _create_vcam(StringName("cam_a"), 5)
	manager.register_vcam(camera_a)
	var follow_target := Node3D.new()
	add_child(follow_target)
	autofree(follow_target)
	manager.test_follow_target = follow_target
	manager.test_occluders = [_create_mesh_occluder()]
	manager.submit_evaluated_camera(StringName("cam_a"), {"transform": Transform3D.IDENTITY})
	store.clear_dispatched_actions()

	manager.unregister_vcam(camera_a)

	var action := _find_last_silhouette_payload(store)
	assert_false(action.is_empty(), "Unregistering active vcam should dispatch silhouette clear request")
	assert_eq(action.get("enabled", true), false, "Unregister clear request should disable silhouettes")
	var occluders := action.get("occluders", []) as Array
	assert_eq(occluders.size(), 0, "Clear request should not include occluders")

func test_scene_transition_blend_clears_active_silhouettes() -> void:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("gameplay"), {"player_entity_id": "player"})
	store.set_slice(StringName("vfx"), {"occlusion_silhouette_enabled": true})
	add_child(store)
	autofree(store)

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)

	var manager := await _create_occlusion_test_manager(store, camera_manager)
	manager.register_vcam(_create_vcam(StringName("cam_a"), 5))
	var follow_target := Node3D.new()
	add_child(follow_target)
	autofree(follow_target)
	manager.test_follow_target = follow_target
	manager.test_occluders = [_create_mesh_occluder()]
	manager.submit_evaluated_camera(StringName("cam_a"), {"transform": Transform3D.IDENTITY})
	store.clear_dispatched_actions()

	camera_manager.blend_active = true
	manager.submit_evaluated_camera(StringName("cam_a"), {"transform": Transform3D.IDENTITY})

	var action := _find_last_silhouette_payload(store)
	assert_false(action.is_empty(), "Scene-transition blend should dispatch silhouette clear request")
	assert_eq(action.get("enabled", true), false, "Transition clear request should disable silhouettes")

func test_set_active_vcam_starts_live_blend_and_publishes_started_event() -> void:
	var store := MOCK_STATE_STORE.new()
	add_child(store)
	autofree(store)
	var manager := await _create_manager(store)
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.blend_duration = 0.5
	var camera_a := _create_vcam(StringName("cam_a"), 5, true, hint)
	var camera_b := _create_vcam(StringName("cam_b"), 1, true, hint)
	manager.register_vcam(camera_a)
	manager.register_vcam(camera_b)
	store.clear_dispatched_actions()

	manager.set_active_vcam(StringName("cam_b"))

	assert_true(manager.is_blending(), "Switch should start a live blend when duration is positive")
	assert_almost_eq(manager.get_blend_progress(), 0.0, 0.0001)
	assert_eq(manager.get_previous_vcam_id(), StringName("cam_a"))

	var start_action: Dictionary = _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_START_BLEND
	)
	assert_false(start_action.is_empty(), "Blend start should dispatch vcam/start_blend")

func test_blend_progress_advances_and_completes_with_completed_event() -> void:
	var store := MOCK_STATE_STORE.new()
	add_child(store)
	autofree(store)
	var manager := await _create_manager(store)
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.blend_duration = 0.4
	manager.register_vcam(_create_vcam(StringName("cam_a"), 5, true, hint))
	manager.register_vcam(_create_vcam(StringName("cam_b"), 1, true, hint))
	store.clear_dispatched_actions()

	manager.set_active_vcam(StringName("cam_b"))
	manager._physics_process(0.2)

	assert_true(manager.get_blend_progress() > 0.0 and manager.get_blend_progress() < 1.0)

	manager._physics_process(0.3)

	assert_false(manager.is_blending(), "Blend should complete after elapsed duration")
	assert_almost_eq(manager.get_blend_progress(), 1.0, 0.0001)
	var complete_action: Dictionary = _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_COMPLETE_BLEND
	)
	assert_false(complete_action.is_empty(), "Blend completion should dispatch vcam/complete_blend")

func test_blend_completes_despite_float_accumulation_undershooting_duration() -> void:
	var store := MOCK_STATE_STORE.new()
	add_child(store)
	autofree(store)
	var manager := await _create_manager(store)
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.blend_duration = 0.2
	manager.register_vcam(_create_vcam(StringName("cam_a"), 5, true, hint))
	manager.register_vcam(_create_vcam(StringName("cam_b"), 1, true, hint))
	store.clear_dispatched_actions()

	manager.set_active_vcam(StringName("cam_b"))

	# Step with 1/60 increments — 12 * (1.0/60.0) = 0.19999999999999998 in IEEE 754,
	# which undershoots 0.200 and can leave _blend_progress at ~0.999999 forever.
	var dt: float = 1.0 / 60.0
	for i in range(15):
		manager._physics_process(dt)

	assert_false(manager.is_blending(), "Blend must complete even when float accumulation undershoots duration")
	assert_almost_eq(manager.get_blend_progress(), 1.0, 0.001)
	var complete_action: Dictionary = _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_COMPLETE_BLEND
	)
	assert_false(complete_action.is_empty(), "Blend completion action must fire despite float precision edge case")

func test_blend_applies_from_two_live_results_not_frozen_outgoing_pose() -> void:
	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)
	var manager := await _create_manager(null, camera_manager)
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.blend_duration = 1.0
	hint.trans_type = Tween.TRANS_LINEAR
	hint.ease_type = Tween.EASE_IN_OUT
	manager.register_vcam(_create_vcam(StringName("cam_a"), 5, true, hint))
	manager.register_vcam(_create_vcam(StringName("cam_b"), 1, true, hint))
	manager.set_active_vcam(StringName("cam_b"))
	manager._physics_process(0.5)

	manager.submit_evaluated_camera(StringName("cam_b"), {
		"transform": Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0)),
		"fov": 70.0,
	})
	manager.submit_evaluated_camera(StringName("cam_a"), {
		"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)),
		"fov": 70.0,
	})
	var first_x: float = camera_manager.last_main_transform.origin.x
	assert_almost_eq(first_x, 5.0, 0.0001)

	manager.submit_evaluated_camera(StringName("cam_b"), {
		"transform": Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0)),
		"fov": 70.0,
	})
	manager.submit_evaluated_camera(StringName("cam_a"), {
		"transform": Transform3D(Basis.IDENTITY, Vector3(100.0, 0.0, 0.0)),
		"fov": 70.0,
	})
	var second_x: float = camera_manager.last_main_transform.origin.x
	assert_gt(second_x, 40.0, "Outgoing camera submission should stay live during blend")

func test_set_active_vcam_with_zero_duration_cuts_without_blend_state() -> void:
	var store := MOCK_STATE_STORE.new()
	add_child(store)
	autofree(store)
	var manager := await _create_manager(store)
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.blend_duration = 1.0
	manager.register_vcam(_create_vcam(StringName("cam_a"), 5, true, hint))
	manager.register_vcam(_create_vcam(StringName("cam_b"), 1, true, hint))
	store.clear_dispatched_actions()

	manager.set_active_vcam(StringName("cam_b"), 0.0)

	assert_false(manager.is_blending(), "Zero-duration switch should cut immediately")
	assert_almost_eq(manager.get_blend_progress(), 1.0, 0.0001)
	var start_action: Dictionary = _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_START_BLEND
	)
	assert_true(start_action.is_empty(), "Cut should not dispatch start_blend")

func test_apply_flow_does_not_apply_previous_frame_submission_when_current_frame_missing() -> void:
	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)
	var manager := await _create_manager(null, camera_manager)
	manager.register_vcam(_create_vcam(StringName("cam_a"), 5))

	manager.submit_evaluated_camera(
		StringName("cam_a"),
		{"transform": Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.0))}
	)
	assert_eq(camera_manager.apply_main_transform_calls, 1)

	await wait_physics_frames(1)

	assert_eq(
		camera_manager.apply_main_transform_calls,
		1,
		"Manager should skip stale previous-frame submissions when no new handoff is present"
	)

func test_reentrant_blend_uses_snapshot_source_and_resets_progress() -> void:
	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)
	var manager := await _create_manager(null, camera_manager)
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.blend_duration = 1.0
	hint.trans_type = Tween.TRANS_LINEAR
	hint.ease_type = Tween.EASE_IN_OUT
	manager.register_vcam(_create_vcam(StringName("cam_a"), 5, true, hint))
	manager.register_vcam(_create_vcam(StringName("cam_b"), 4, true, hint))
	manager.register_vcam(_create_vcam(StringName("cam_c"), 3, true, hint))
	manager.set_active_vcam(StringName("cam_b"))
	manager._physics_process(0.5)
	manager.submit_evaluated_camera(StringName("cam_b"), {
		"transform": Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0)),
		"fov": 70.0,
	})
	manager.submit_evaluated_camera(StringName("cam_a"), {
		"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)),
		"fov": 70.0,
	})
	var snapshot_x: float = camera_manager.last_main_transform.origin.x
	assert_almost_eq(snapshot_x, 5.0, 0.0001)

	manager.set_active_vcam(StringName("cam_c"))
	assert_true(manager.is_blending())
	assert_almost_eq(manager.get_blend_progress(), 0.0, 0.0001, "Reentry should reset blend progress")

	manager._physics_process(0.5)
	manager.submit_evaluated_camera(StringName("cam_c"), {
		"transform": Transform3D(Basis.IDENTITY, Vector3(20.0, 0.0, 0.0)),
		"fov": 70.0,
	})
	var reentered_x: float = camera_manager.last_main_transform.origin.x
	assert_true(
		reentered_x > snapshot_x and reentered_x < 20.0,
		"Reentrant blend should interpolate from the blended snapshot toward the new target"
	)

func test_rapid_reentrant_switches_do_not_wedge_blend_state() -> void:
	var manager := await _create_manager()
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.blend_duration = 0.5
	manager.register_vcam(_create_vcam(StringName("cam_a"), 5, true, hint))
	manager.register_vcam(_create_vcam(StringName("cam_b"), 4, true, hint))
	manager.register_vcam(_create_vcam(StringName("cam_c"), 3, true, hint))
	manager.register_vcam(_create_vcam(StringName("cam_d"), 2, true, hint))

	manager.set_active_vcam(StringName("cam_b"))
	manager.set_active_vcam(StringName("cam_c"))
	manager.set_active_vcam(StringName("cam_d"))
	assert_true(manager.is_blending())

	manager._physics_process(0.8)

	assert_false(manager.is_blending(), "Rapid reentry should still converge and clear blend state")
	assert_eq(manager.get_active_vcam_id(), StringName("cam_d"))

func test_recovery_when_outgoing_vcam_is_freed_completes_to_incoming() -> void:
	var store := MOCK_STATE_STORE.new()
	add_child(store)
	autofree(store)
	var manager := await _create_manager(store)
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.blend_duration = 1.0
	var camera_a := _create_vcam(StringName("cam_a"), 5, true, hint)
	var camera_b := _create_vcam(StringName("cam_b"), 4, true, hint)
	manager.register_vcam(camera_a)
	manager.register_vcam(camera_b)
	store.clear_dispatched_actions()

	manager.set_active_vcam(StringName("cam_b"))
	camera_a.queue_free()
	await get_tree().process_frame
	manager._physics_process(0.016)

	assert_false(manager.is_blending())
	assert_eq(manager.get_active_vcam_id(), StringName("cam_b"))
	var recovery_action: Dictionary = _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_RECORD_RECOVERY
	)
	var payload := recovery_action.get("payload", {}) as Dictionary
	assert_eq(String(payload.get("reason", "")), "blend_from_invalid")

func test_recovery_when_incoming_vcam_is_freed_cancels_blend_and_reselects() -> void:
	var store := MOCK_STATE_STORE.new()
	add_child(store)
	autofree(store)
	var manager := await _create_manager(store)
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.blend_duration = 1.0
	var camera_a := _create_vcam(StringName("cam_a"), 5, true, hint)
	var camera_b := _create_vcam(StringName("cam_b"), 4, true, hint)
	manager.register_vcam(camera_a)
	manager.register_vcam(camera_b)
	store.clear_dispatched_actions()

	manager.set_active_vcam(StringName("cam_b"))
	camera_b.queue_free()
	await get_tree().process_frame
	manager._physics_process(0.016)

	assert_false(manager.is_blending())
	assert_eq(manager.get_active_vcam_id(), StringName("cam_a"))
	var recovery_action: Dictionary = _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_RECORD_RECOVERY
	)
	var payload := recovery_action.get("payload", {}) as Dictionary
	assert_eq(String(payload.get("reason", "")), "blend_to_invalid")

func test_recovery_when_both_blend_vcams_are_freed_records_both_invalid() -> void:
	var store := MOCK_STATE_STORE.new()
	add_child(store)
	autofree(store)
	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)
	var manager := await _create_manager(store, camera_manager)
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.blend_duration = 1.0
	hint.trans_type = Tween.TRANS_LINEAR
	hint.ease_type = Tween.EASE_IN_OUT
	var camera_a := _create_vcam(StringName("cam_a"), 5, true, hint)
	var camera_b := _create_vcam(StringName("cam_b"), 4, true, hint)
	manager.register_vcam(camera_a)
	manager.register_vcam(camera_b)
	manager.set_active_vcam(StringName("cam_b"))
	manager._physics_process(0.5)
	manager.submit_evaluated_camera(StringName("cam_b"), {
		"transform": Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0)),
		"fov": 70.0,
	})
	manager.submit_evaluated_camera(StringName("cam_a"), {
		"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)),
		"fov": 70.0,
	})
	var held_x: float = camera_manager.last_main_transform.origin.x
	store.clear_dispatched_actions()

	camera_a.queue_free()
	camera_b.queue_free()
	await get_tree().process_frame
	manager._physics_process(0.016)

	assert_false(manager.is_blending())
	assert_eq(manager.get_active_vcam_id(), StringName(""))
	assert_almost_eq(camera_manager.last_main_transform.origin.x, held_x, 0.0001)
	var recovery_action: Dictionary = _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_RECORD_RECOVERY
	)
	var payload := recovery_action.get("payload", {}) as Dictionary
	assert_eq(String(payload.get("reason", "")), "blend_both_invalid")

func test_live_blend_suppresses_occlusion_and_clears_silhouettes() -> void:
	var store := MOCK_STATE_STORE.new()
	store.set_slice(StringName("gameplay"), {"player_entity_id": "player"})
	store.set_slice(StringName("vfx"), {"occlusion_silhouette_enabled": true})
	add_child(store)
	autofree(store)

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)

	var manager := await _create_occlusion_test_manager(store, camera_manager)
	var hint := RS_VCAM_BLEND_HINT.new()
	hint.blend_duration = 1.0
	hint.trans_type = Tween.TRANS_LINEAR
	hint.ease_type = Tween.EASE_IN_OUT

	var camera_orbit := _create_vcam(StringName("cam_orbit"), 5, true, hint)
	var camera_secondary := _create_vcam(StringName("cam_secondary"), 1, true, hint)
	manager.register_vcam(camera_orbit)
	manager.register_vcam(camera_secondary)

	# Set up occlusion so orbit produces 2 occluders
	var follow_target := Node3D.new()
	add_child(follow_target)
	autofree(follow_target)
	manager.test_follow_target = follow_target
	var occluder_a := _create_mesh_occluder()
	var occluder_b := _create_mesh_occluder()
	manager.test_occluders = [occluder_a, occluder_b]

	# Confirm orbit publishes occluders normally
	manager.submit_evaluated_camera(StringName("cam_orbit"), {
		"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 5.0, -10.0)),
	})
	var pre_blend_action := _find_last_silhouette_payload(store)
	assert_eq((pre_blend_action.get("occluders", []) as Array).size(), 2,
		"Pre-blend orbit should publish detected occluders")

	# Start blend from orbit -> secondary camera
	manager.set_active_vcam(StringName("cam_secondary"))
	assert_true(manager.is_blending(), "Blend should be active after set_active_vcam")
	store.clear_dispatched_actions()

	# Submit during blend — occluders should be suppressed
	manager.submit_evaluated_camera(StringName("cam_secondary"), {
		"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, -2.0)),
		"fov": 60.0,
	})
	manager.submit_evaluated_camera(StringName("cam_orbit"), {
		"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 5.0, -10.0)),
		"fov": 70.0,
	})

	var during_blend_action := _find_last_silhouette_payload(store)
	assert_false(during_blend_action.is_empty(),
		"Silhouette clear request should be dispatched during blend")
	assert_eq(during_blend_action.get("enabled", true), false,
		"Silhouette request during blend should disable silhouettes")
	var during_occluders := during_blend_action.get("occluders", []) as Array
	assert_eq(during_occluders.size(), 0,
		"No occluders should be dispatched during blend")

func _create_manager(
	injected_store: I_StateStore = null,
	injected_camera_manager: I_CameraManager = null
) -> M_VCamManager:
	var manager := M_VCAM_MANAGER.new()
	if injected_store != null:
		manager.state_store = injected_store
	if injected_camera_manager != null:
		manager.camera_manager = injected_camera_manager
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame
	return manager

func _create_occlusion_test_manager(
	injected_store: I_StateStore = null,
	injected_camera_manager: I_CameraManager = null
) -> VCamManagerOcclusionStub:
	var manager := VCamManagerOcclusionStub.new()
	if injected_store != null:
		manager.state_store = injected_store
	if injected_camera_manager != null:
		manager.camera_manager = injected_camera_manager
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame
	return manager

func _create_vcam(
	vcam_id: StringName,
	priority: int,
	active: bool = true,
	blend_hint: Resource = null
) -> C_VCamComponent:
	var component := C_VCAM_COMPONENT.new()
	component.vcam_id = vcam_id
	component.priority = priority
	component.is_active = active
	component.mode = RS_VCAM_MODE_ORBIT.new()
	component.blend_hint = blend_hint
	add_child(component)
	autofree(component)
	return component

func _create_mesh_occluder() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	add_child(mesh)
	autofree(mesh)
	return mesh

func _find_last_silhouette_payload(store: I_StateStore) -> Dictionary:
	var action: Dictionary = _find_last_action_by_type(
		store.get_dispatched_actions(),
		U_VCAM_ACTIONS.ACTION_SILHOUETTE_UPDATE_REQUEST
	)
	if action.is_empty():
		return {}
	return action.duplicate(true)

func _find_last_action_by_type(actions: Array, action_type: StringName) -> Dictionary:
	for i in range(actions.size() - 1, -1, -1):
		var action_variant: Variant = actions[i]
		if not (action_variant is Dictionary):
			continue
		var action := action_variant as Dictionary
		if action.get("type", StringName("")) == action_type:
			return action.duplicate(true)
	return {}
