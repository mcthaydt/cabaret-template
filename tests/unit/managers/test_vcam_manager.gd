extends BaseTest

const M_VCAM_MANAGER := preload("res://scripts/managers/m_vcam_manager.gd")
const I_VCAM_MANAGER := preload("res://scripts/interfaces/i_vcam_manager.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const RS_VCAM_MODE_ORBIT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/events/ecs/u_ecs_event_names.gd")
const U_VCAM_ACTIONS := preload("res://scripts/state/actions/u_vcam_actions.gd")

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_ECS_EVENT_BUS.reset()

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_ECS_EVENT_BUS.reset()

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
	var manager := await _create_manager()
	manager.register_vcam(_create_vcam(StringName("cam_a"), 1))
	manager.register_vcam(_create_vcam(StringName("cam_b"), 5))
	U_ECS_EVENT_BUS.clear_history()

	manager.set_active_vcam(StringName("cam_a"))

	var history: Array = U_ECS_EVENT_BUS.get_event_history()
	assert_eq(history.size(), 1, "Active switch should publish one ECS event")
	var event_payload := history[0] as Dictionary
	assert_eq(event_payload.get("name", StringName("")), U_ECS_EVENT_NAMES.EVENT_VCAM_ACTIVE_CHANGED)
	var payload := event_payload.get("payload", {}) as Dictionary
	assert_eq(payload.get("vcam_id", StringName("")), StringName("cam_a"))
	assert_eq(payload.get("previous_vcam_id", StringName("")), StringName("cam_b"))
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

func _create_manager(injected_store: I_StateStore = null) -> M_VCamManager:
	var manager := M_VCAM_MANAGER.new()
	if injected_store != null:
		manager.state_store = injected_store
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame
	return manager

func _create_vcam(vcam_id: StringName, priority: int, active: bool = true) -> C_VCamComponent:
	var component := C_VCAM_COMPONENT.new()
	component.vcam_id = vcam_id
	component.priority = priority
	component.is_active = active
	component.mode = RS_VCAM_MODE_ORBIT.new()
	add_child(component)
	autofree(component)
	return component
