extends BaseTest

const CAMERA_STATE_SYSTEM := preload("res://scripts/core/ecs/systems/s_camera_state_system.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")

const BASE_ECS_ENTITY := preload("res://scripts/core/ecs/base_ecs_entity.gd")
const C_CAMERA_STATE_COMPONENT := preload("res://scripts/core/ecs/components/c_camera_state_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/core/ecs/components/c_movement_component.gd")

const RULE_RESOURCE := preload("res://scripts/core/resources/qb/rs_rule.gd")
const CONDITION_CONSTANT := preload("res://scripts/core/resources/qb/conditions/rs_condition_constant.gd")
const CONDITION_ENTITY_TAG := preload("res://scripts/core/resources/qb/conditions/rs_condition_entity_tag.gd")
const EFFECT_SET_FIELD := preload("res://scripts/core/resources/qb/effects/rs_effect_set_field.gd")
const SPEED_FOV_RULE := preload("res://resources/core/qb/camera/cfg_camera_speed_fov_rule.tres")

const I_CONDITION := preload("res://scripts/core/interfaces/i_condition.gd")
const I_EFFECT := preload("res://scripts/core/interfaces/i_effect.gd")

func before_each() -> void:
	U_ECSEventBus.reset()

func test_default_rules_loaded_and_pass_validation() -> void:
	var fixture: Dictionary = _create_fixture()
	var system: Variant = fixture.get("system", null)
	assert_not_null(system)

	var report: Dictionary = system.get_rule_validation_report()
	var errors_by_index: Dictionary = report.get("errors_by_index", {}) as Dictionary
	assert_true(errors_by_index.is_empty(), "Default camera rules should validate with zero errors")

	var valid_rules_variant: Variant = report.get("valid_rules", [])
	assert_true(valid_rules_variant is Array)
	var valid_rules: Array = valid_rules_variant as Array
	assert_eq(valid_rules.size(), 4)

	var rule_ids: Array[StringName] = []
	for rule_variant in valid_rules:
		if rule_variant == null or not (rule_variant is Object):
			continue
		rule_ids.append(rule_variant.get("rule_id") as StringName)
	assert_true(rule_ids.has(StringName("camera_shake")))
	assert_true(rule_ids.has(StringName("camera_zone_fov")))
	assert_true(rule_ids.has(StringName("camera_speed_fov")))
	assert_true(rule_ids.has(StringName("camera_landing_impact")))

func test_shake_trauma_added_on_entity_death_event() -> void:
	var fixture: Dictionary = _create_fixture()
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(camera_state)

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_ENTITY_DEATH, {"entity_id": StringName("player")})

	assert_almost_eq(camera_state.shake_trauma, 0.5, 0.001)

func test_shake_trauma_clamped_to_one_on_repeated_events() -> void:
	var fixture: Dictionary = _create_fixture()
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(camera_state)

	for _i in range(3):
		U_ECSEventBus.publish(U_ECSEventNames.EVENT_ENTITY_DEATH, {"entity_id": StringName("player")})

	assert_almost_eq(camera_state.shake_trauma, 1.0, 0.001)

func test_fov_zone_sets_target_fov_when_redux_flag_true() -> void:
	var fixture: Dictionary = _create_fixture([], [], 90.0)
	var store: MockStateStore = fixture.get("store") as MockStateStore
	var system: Variant = fixture.get("system", null)
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(store)
	assert_not_null(system)
	assert_not_null(camera_state)

	store.set_slice(StringName("vcam"), {
		"in_fov_zone": true,
	})
	system.process_tick(0.016)

	assert_almost_eq(camera_state.target_fov, 60.0, 0.001)

func test_fov_blending_lerps_main_camera_toward_target() -> void:
	var fixture: Dictionary = _create_fixture([], [], 90.0)
	var store: MockStateStore = fixture.get("store") as MockStateStore
	var system: Variant = fixture.get("system", null)
	var camera_manager: MockCameraManager = fixture.get("camera_manager") as MockCameraManager
	assert_not_null(store)
	assert_not_null(system)
	assert_not_null(camera_manager)
	assert_not_null(camera_manager.main_camera)

	store.set_slice(StringName("vcam"), {
		"in_fov_zone": true,
	})
	system.process_tick(0.25)

	assert_almost_eq(camera_manager.main_camera.fov, 82.5, 0.001)

func test_speed_fov_rule_sets_bonus_from_movement_speed() -> void:
	var fixture: Dictionary = _create_fixture(
		[],
		[
			{"name": "E_Camera", "tags": [], "movement_velocity": Vector2(4.5, 0.0)},
		],
		90.0
	)
	var system: Variant = fixture.get("system", null)
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(system)
	assert_not_null(camera_state)

	system.process_tick(0.016)

	var expected_bonus: float = _compute_speed_fov_bonus_after_component_clamp(
		4.5,
		camera_state.speed_fov_max_bonus
	)
	assert_almost_eq(camera_state.speed_fov_bonus, expected_bonus, 0.001)

func test_stationary_speed_sets_speed_fov_bonus_to_zero() -> void:
	var fixture: Dictionary = _create_fixture(
		[],
		[
			{"name": "E_Camera", "tags": [], "movement_velocity": Vector2.ZERO},
		],
		90.0
	)
	var system: Variant = fixture.get("system", null)
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(system)
	assert_not_null(camera_state)

	system.process_tick(0.016)

	var expected_bonus: float = _compute_speed_fov_bonus_after_component_clamp(
		0.0,
		camera_state.speed_fov_max_bonus
	)
	assert_almost_eq(camera_state.speed_fov_bonus, expected_bonus, 0.001)

func test_speed_fov_bonus_is_clamped_to_component_max() -> void:
	var rule_bonus_at_high_speed: float = _compute_speed_fov_rule_bonus(99.0)
	assert_gt(rule_bonus_at_high_speed, 0.0, "Speed-FOV rule should produce a positive bonus at high speed")
	var forced_max_bonus: float = maxf(rule_bonus_at_high_speed * 0.5, 0.1)

	var fixture: Dictionary = _create_fixture(
		[],
		[
			{
				"name": "E_Camera",
				"tags": [],
				"movement_velocity": Vector2(99.0, 0.0),
				"speed_fov_max_bonus": forced_max_bonus,
			},
		],
		90.0
	)
	var system: Variant = fixture.get("system", null)
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(system)
	assert_not_null(camera_state)

	system.process_tick(0.016)

	var expected_bonus: float = _compute_speed_fov_bonus_after_component_clamp(
		99.0,
		forced_max_bonus
	)
	assert_almost_eq(camera_state.speed_fov_bonus, expected_bonus, 0.001)

func test_resolve_target_fov_adds_speed_fov_bonus_to_base_target() -> void:
	var fixture: Dictionary = _create_fixture(
		[],
		[
			{
				"name": "E_Camera",
				"tags": [],
				"movement_velocity": Vector2(4.5, 0.0),
				"fov_blend_speed": 99.0,
			},
		],
		90.0
	)
	var system: Variant = fixture.get("system", null)
	var camera_manager: MockCameraManager = fixture.get("camera_manager") as MockCameraManager
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(system)
	assert_not_null(camera_manager)
	assert_not_null(camera_manager.main_camera)
	assert_not_null(camera_state)

	system.process_tick(0.25)

	var expected_bonus: float = _compute_speed_fov_bonus_after_component_clamp(
		4.5,
		camera_state.speed_fov_max_bonus
	)
	var expected_target_fov: float = 90.0 + expected_bonus
	assert_almost_eq(camera_state.target_fov, expected_target_fov, 0.001)
	assert_almost_eq(camera_manager.main_camera.fov, expected_target_fov, 0.001)

func test_fov_blend_speed_smooths_speed_fov_transition() -> void:
	var fixture: Dictionary = _create_fixture(
		[],
		[
			{
				"name": "E_Camera",
				"tags": [],
				"movement_velocity": Vector2(9.0, 0.0),
				"fov_blend_speed": 2.0,
			},
		],
		90.0
	)
	var system: Variant = fixture.get("system", null)
	var camera_manager: MockCameraManager = fixture.get("camera_manager") as MockCameraManager
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(system)
	assert_not_null(camera_manager)
	assert_not_null(camera_manager.main_camera)
	assert_not_null(camera_state)

	system.process_tick(0.1)

	var expected_bonus: float = _compute_speed_fov_bonus_after_component_clamp(
		9.0,
		camera_state.speed_fov_max_bonus
	)
	var expected_target_fov: float = 90.0 + expected_bonus
	var expected_fov: float = lerpf(90.0, expected_target_fov, clampf(2.0 * 0.1, 0.0, 1.0))
	assert_almost_eq(camera_manager.main_camera.fov, expected_fov, 0.001)
	assert_true(camera_manager.main_camera.fov < expected_target_fov)

func test_landing_event_sets_max_landing_impact_offset() -> void:
	var fixture: Dictionary = _create_fixture([], [], 90.0)
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(camera_state)

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_ENTITY_LANDED, {
		"entity_id": StringName("player"),
		"fall_speed": 30.0,
	})

	assert_almost_eq(camera_state.landing_impact_offset.x, 0.0, 0.0001)
	assert_almost_eq(camera_state.landing_impact_offset.y, -0.3, 0.0001)
	assert_almost_eq(camera_state.landing_impact_offset.z, 0.0, 0.0001)

func test_landing_event_scales_landing_impact_offset_by_fall_speed() -> void:
	var fixture: Dictionary = _create_fixture([], [], 90.0)
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(camera_state)

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_ENTITY_LANDED, {
		"entity_id": StringName("player"),
		"fall_speed": 17.5,
	})

	assert_almost_eq(camera_state.landing_impact_offset.y, -0.15, 0.0001)

func test_landing_event_below_threshold_resets_landing_impact_offset_to_zero() -> void:
	var fixture: Dictionary = _create_fixture([], [], 90.0)
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(camera_state)
	camera_state.landing_impact_offset = Vector3(0.0, -0.2, 0.0)

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_ENTITY_LANDED, {
		"entity_id": StringName("player"),
		"fall_speed": 1.0,
	})

	assert_true(camera_state.landing_impact_offset.is_equal_approx(Vector3.ZERO))

func test_non_landing_event_does_not_change_landing_impact_offset() -> void:
	var fixture: Dictionary = _create_fixture([], [], 90.0)
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(camera_state)
	camera_state.landing_impact_offset = Vector3(0.0, -0.12, 0.0)

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_ENTITY_DEATH, {
		"entity_id": StringName("player"),
	})

	assert_almost_eq(camera_state.landing_impact_offset.y, -0.12, 0.0001)

func test_baseline_fov_captured_from_authored_camera_on_first_tick() -> void:
	var fixture: Dictionary = _create_fixture([], [], 82.3)
	var system: Variant = fixture.get("system", null)
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(system)
	assert_not_null(camera_state)

	system.process_tick(0.016)

	assert_almost_eq(camera_state.base_fov, 82.3, 0.001)

func test_baseline_fov_restored_when_zone_becomes_inactive() -> void:
	var fixture: Dictionary = _create_fixture([], [], 90.0)
	var store: MockStateStore = fixture.get("store") as MockStateStore
	var system: Variant = fixture.get("system", null)
	var camera_manager: MockCameraManager = fixture.get("camera_manager") as MockCameraManager
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(store)
	assert_not_null(system)
	assert_not_null(camera_manager)
	assert_not_null(camera_manager.main_camera)
	assert_not_null(camera_state)

	store.set_slice(StringName("vcam"), {
		"in_fov_zone": true,
	})
	system.process_tick(1.0)
	assert_almost_eq(camera_manager.main_camera.fov, 60.0, 0.001)

	store.set_slice(StringName("vcam"), {
		"in_fov_zone": false,
	})
	system.process_tick(1.0)

	assert_almost_eq(camera_state.target_fov, 90.0, 0.001)
	assert_almost_eq(camera_manager.main_camera.fov, 90.0, 0.001)

func test_designer_rules_via_export_are_evaluated_alongside_defaults() -> void:
	var designer_rules: Array = [
		_make_tick_set_field_rule(StringName("designer_set_blend"), StringName("fov_blend_speed"), 5.0),
	]
	var fixture: Dictionary = _create_fixture(designer_rules, [], 90.0)
	var store: MockStateStore = fixture.get("store") as MockStateStore
	var system: Variant = fixture.get("system", null)
	var camera_state: C_CameraStateComponent = fixture.get("camera_state") as C_CameraStateComponent
	assert_not_null(store)
	assert_not_null(system)
	assert_not_null(camera_state)

	store.set_slice(StringName("vcam"), {
		"in_fov_zone": true,
	})
	system.process_tick(0.016)

	assert_almost_eq(camera_state.target_fov, 60.0, 0.001)
	assert_almost_eq(camera_state.fov_blend_speed, 5.0, 0.001)

func test_entity_death_event_fans_out_to_all_camera_entities() -> void:
	var fixture: Dictionary = _create_fixture(
		[],
		[
			{"name": "E_Camera", "tags": []},
			{"name": "E_Secondary", "tags": []},
		],
		90.0
	)
	var camera_states: Array = fixture.get("camera_states", []) as Array
	assert_eq(camera_states.size(), 2)

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_ENTITY_DEATH, {"entity_id": StringName("player")})

	for state_variant in camera_states:
		var state: C_CameraStateComponent = state_variant as C_CameraStateComponent
		assert_not_null(state)
		if state == null:
			continue
		assert_almost_eq(state.shake_trauma, 0.5, 0.001)

func test_non_primary_camera_trauma_decays_each_tick() -> void:
	var fixture: Dictionary = _create_fixture(
		[],
		[
			{"name": "E_Camera", "tags": []},
			{"name": "E_Secondary", "tags": []},
		],
		90.0
	)
	var system: Variant = fixture.get("system", null)
	var camera_states: Array = fixture.get("camera_states", []) as Array
	assert_not_null(system)
	assert_eq(camera_states.size(), 2)

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_ENTITY_DEATH, {"entity_id": StringName("player")})
	system.process_tick(0.25)

	for state_variant in camera_states:
		var state: C_CameraStateComponent = state_variant as C_CameraStateComponent
		assert_not_null(state)
		if state == null:
			continue
		assert_almost_eq(state.shake_trauma, 0.0, 0.001)

func test_primary_camera_selection_prefers_entity_id_or_camera_tag() -> void:
	var selector_rule: RS_Rule = _make_tag_target_fov_rule(
		StringName("focus_fov_rule"),
		StringName("focus"),
		30.0
	)

	var fixture_by_id: Dictionary = _create_fixture(
		[selector_rule],
		[
			{"name": "E_Camera", "tags": []},
			{"name": "E_Other", "tags": [StringName("focus")]},
		],
		90.0
	)
	var store_by_id: MockStateStore = fixture_by_id.get("store") as MockStateStore
	var system_by_id: Variant = fixture_by_id.get("system", null)
	var camera_manager_by_id: MockCameraManager = fixture_by_id.get("camera_manager") as MockCameraManager
	assert_not_null(store_by_id)
	assert_not_null(system_by_id)
	assert_not_null(camera_manager_by_id)
	assert_not_null(camera_manager_by_id.main_camera)

	store_by_id.set_slice(StringName("vcam"), {"in_fov_zone": true})
	system_by_id.process_tick(1.0)
	assert_almost_eq(camera_manager_by_id.main_camera.fov, 60.0, 0.001)

	var fixture_by_tag: Dictionary = _create_fixture(
		[selector_rule],
		[
			{"name": "E_Main", "tags": []},
			{"name": "E_Tagged", "tags": [StringName("camera"), StringName("focus")]},
		],
		90.0
	)
	var store_by_tag: MockStateStore = fixture_by_tag.get("store") as MockStateStore
	var system_by_tag: Variant = fixture_by_tag.get("system", null)
	var camera_manager_by_tag: MockCameraManager = fixture_by_tag.get("camera_manager") as MockCameraManager
	assert_not_null(store_by_tag)
	assert_not_null(system_by_tag)
	assert_not_null(camera_manager_by_tag)
	assert_not_null(camera_manager_by_tag.main_camera)

	store_by_tag.set_slice(StringName("vcam"), {"in_fov_zone": true})
	system_by_tag.process_tick(1.0)
	assert_almost_eq(camera_manager_by_tag.main_camera.fov, 30.0, 0.001)

func test_camera_context_includes_vcam_runtime_fields_for_qb_rules() -> void:
	var fixture: Dictionary = _create_fixture([], [], 90.0)
	var store: MockStateStore = fixture.get("store") as MockStateStore
	var system: Variant = fixture.get("system", null)
	assert_not_null(store)
	assert_not_null(system)

	store.set_slice(StringName("vcam"), {
		"in_fov_zone": false,
		"active_mode": "orbit",
		"is_blending": true,
		"active_vcam_id": StringName("cam_orbit"),
	})

	var contexts_variant: Variant = system.call("_build_camera_contexts", StringName(), {})
	assert_true(contexts_variant is Array)
	var contexts: Array = contexts_variant as Array
	assert_false(contexts.is_empty())
	var context: Dictionary = contexts[0] as Dictionary
	# Dictionary keys are StringName after RSRuleContext migration, use U_RuleUtils for lookups
	var U_RULE_UTILS := load("res://scripts/core/utils/ecs/u_rule_utils.gd")
	var rule_utils: RefCounted = U_RULE_UTILS.new()
	assert_eq(String(rule_utils.call("get_context_value", context, "vcam_active_mode")), "orbit")
	assert_eq(bool(rule_utils.call("get_context_value", context, "vcam_is_blending")), true)
	assert_eq(rule_utils.call("get_context_value", context, "vcam_active_vcam_id"), StringName("cam_orbit"))

func _create_fixture(designer_rules: Array = [], entity_specs: Array = [], main_camera_fov: float = 90.0) -> Dictionary:
	var store := MOCK_STATE_STORE.new()
	autofree(store)
	store.set_slice(StringName("vcam"), {
		"in_fov_zone": false,
	})

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	autofree(camera_manager)
	var main_camera := Camera3D.new()
	autofree(main_camera)
	main_camera.fov = main_camera_fov
	camera_manager.main_camera = main_camera

	var system := CAMERA_STATE_SYSTEM.new()
	autofree(system)
	system.state_store = store
	system.ecs_manager = ecs_manager
	system.camera_manager = camera_manager
	add_child(system)

	var typed_rules: Array[RS_Rule] = []
	for rule_variant in designer_rules:
		if rule_variant is RS_Rule:
			typed_rules.append(rule_variant)
	system.rules = typed_rules
	system.configure(ecs_manager)

	var specs: Array = entity_specs.duplicate(true)
	if specs.is_empty():
		specs.append({"name": "E_Camera", "tags": []})

	var camera_states: Array = []
	var entities_by_name: Dictionary = {}
	for spec_variant in specs:
		if not (spec_variant is Dictionary):
			continue
		var registered: Dictionary = _register_camera_entity(ecs_manager, spec_variant as Dictionary)
		var entity: BaseECSEntity = registered.get("entity") as BaseECSEntity
		var camera_state: C_CameraStateComponent = registered.get("camera_state") as C_CameraStateComponent
		if entity != null:
			entities_by_name[String(entity.name)] = entity
		if camera_state != null:
			camera_states.append(camera_state)

	return {
		"system": system,
		"store": store,
		"ecs_manager": ecs_manager,
		"camera_manager": camera_manager,
		"camera_state": camera_states[0] if not camera_states.is_empty() else null,
		"camera_states": camera_states,
		"entities_by_name": entities_by_name,
	}

func _register_camera_entity(ecs_manager: MockECSManager, spec: Dictionary) -> Dictionary:
	var entity := BASE_ECS_ENTITY.new()
	autofree(entity)
	var entity_name: String = String(spec.get("name", "E_Camera"))
	entity.name = entity_name
	var tags_variant: Variant = spec.get("tags", [])
	if tags_variant is Array:
		var resolved_tags: Array[StringName] = []
		for tag_variant in tags_variant as Array:
			if tag_variant is StringName:
				resolved_tags.append(tag_variant)
			elif tag_variant is String:
				var tag_text: String = tag_variant
				if not tag_text.is_empty():
					resolved_tags.append(StringName(tag_text))
		entity.tags = resolved_tags

	var camera_state := C_CAMERA_STATE_COMPONENT.new()
	autofree(camera_state)
	if spec.has("target_fov"):
		camera_state.target_fov = float(spec.get("target_fov", C_CAMERA_STATE_COMPONENT.DEFAULT_TARGET_FOV))
	if spec.has("base_fov"):
		camera_state.base_fov = float(spec.get("base_fov", C_CAMERA_STATE_COMPONENT.UNSET_BASE_FOV))
	if spec.has("shake_trauma"):
		camera_state.shake_trauma = float(spec.get("shake_trauma", C_CAMERA_STATE_COMPONENT.DEFAULT_SHAKE_TRAUMA))
	if spec.has("fov_blend_speed"):
		camera_state.fov_blend_speed = float(spec.get("fov_blend_speed", C_CAMERA_STATE_COMPONENT.DEFAULT_FOV_BLEND_SPEED))
	if spec.has("speed_fov_max_bonus"):
		camera_state.speed_fov_max_bonus = float(spec.get("speed_fov_max_bonus", C_CAMERA_STATE_COMPONENT.DEFAULT_SPEED_FOV_MAX_BONUS))

	entity.add_child(camera_state)
	ecs_manager.add_component_to_entity(entity, camera_state)

	if spec.has("movement_velocity"):
		var movement_component := C_MOVEMENT_COMPONENT.new()
		autofree(movement_component)
		var velocity_variant: Variant = spec.get("movement_velocity", Vector2.ZERO)
		var movement_velocity: Vector2 = Vector2.ZERO
		if velocity_variant is Vector2:
			movement_velocity = velocity_variant as Vector2
		elif velocity_variant is Vector3:
			var velocity_3d: Vector3 = velocity_variant as Vector3
			movement_velocity = Vector2(velocity_3d.x, velocity_3d.z)
		movement_component.set_horizontal_dynamics_velocity(movement_velocity)
		entity.add_child(movement_component)
		ecs_manager.add_component_to_entity(entity, movement_component)

	ecs_manager.register_entity_id(entity.get_entity_id(), entity)

	return {
		"entity": entity,
		"camera_state": camera_state,
	}

func _compute_speed_fov_rule_bonus(speed_magnitude: float) -> float:
	var rule_resource: Resource = SPEED_FOV_RULE
	if rule_resource == null:
		return 0.0

	var conditions_variant: Variant = rule_resource.get("conditions")
	if not (conditions_variant is Array):
		return 0.0
	var conditions: Array = conditions_variant as Array
	if conditions.is_empty():
		return 0.0
	var condition_variant: Variant = conditions[0]
	if condition_variant == null or not (condition_variant is Object):
		return 0.0
	var condition := condition_variant as Object
	var range_min: float = _read_object_float(condition, "range_min", 0.0)
	var range_max: float = _read_object_float(condition, "range_max", 1.0)
	var score: float = 0.0
	if is_equal_approx(range_min, range_max):
		score = 1.0 if speed_magnitude >= range_min else 0.0
	else:
		score = clampf((speed_magnitude - range_min) / (range_max - range_min), 0.0, 1.0)

	var threshold: float = _read_object_float(rule_resource, "score_threshold", 0.0)
	if score <= threshold:
		return 0.0

	var effects_variant: Variant = rule_resource.get("effects")
	if not (effects_variant is Array):
		return 0.0
	var effects: Array = effects_variant as Array
	if effects.is_empty():
		return 0.0
	var effect_variant: Variant = effects[0]
	if effect_variant == null or not (effect_variant is Object):
		return 0.0
	var effect := effect_variant as Object
	var bonus: float = _read_object_float(effect, "float_value", 0.0)
	if _read_object_bool(effect, "scale_by_rule_score", false):
		bonus *= score
	if _read_object_bool(effect, "use_clamp", false):
		var clamp_min: float = _read_object_float(effect, "clamp_min", 0.0)
		var clamp_max: float = _read_object_float(effect, "clamp_max", 1.0)
		bonus = clampf(bonus, clamp_min, clamp_max)
	return maxf(bonus, 0.0)

func _compute_speed_fov_bonus_after_component_clamp(speed_magnitude: float, component_max_bonus: float) -> float:
	return clampf(_compute_speed_fov_rule_bonus(speed_magnitude), 0.0, maxf(component_max_bonus, 0.0))

func _read_object_float(object_value: Object, property_name: String, fallback: float) -> float:
	if object_value == null:
		return fallback
	var value: Variant = object_value.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback

func _read_object_bool(object_value: Object, property_name: String, fallback: bool) -> bool:
	if object_value == null:
		return fallback
	var value: Variant = object_value.get(property_name)
	if value is bool:
		return bool(value)
	return fallback

func _make_constant_condition() -> RS_ConditionConstant:
	var condition := CONDITION_CONSTANT.new()
	condition.score = 1.0
	return condition

func _make_tick_set_field_rule(rule_id: StringName, field_name: StringName, float_value: float) -> RS_Rule:
	var effect := EFFECT_SET_FIELD.new()
	effect.component_type = C_CAMERA_STATE_COMPONENT.COMPONENT_TYPE
	effect.field_name = field_name
	effect.operation = "set"
	effect.value_type = "float"
	effect.float_value = float_value

	var rule := RULE_RESOURCE.new()
	rule.rule_id = rule_id
	rule.trigger_mode = "tick"
	rule.conditions.clear()
	rule.conditions.append(_make_constant_condition() as I_Condition)
	rule.effects.clear()
	rule.effects.append(effect as I_Effect)
	return rule

func _make_tag_target_fov_rule(rule_id: StringName, required_tag: StringName, fov_value: float) -> RS_Rule:
	var condition := CONDITION_ENTITY_TAG.new()
	condition.tag_name = required_tag

	var effect := EFFECT_SET_FIELD.new()
	effect.component_type = C_CAMERA_STATE_COMPONENT.COMPONENT_TYPE
	effect.field_name = StringName("target_fov")
	effect.operation = "set"
	effect.value_type = "float"
	effect.float_value = fov_value

	var rule := RULE_RESOURCE.new()
	rule.rule_id = rule_id
	rule.trigger_mode = "tick"
	rule.conditions.clear()
	rule.conditions.append(condition as I_Condition)
	rule.effects.clear()
	rule.effects.append(effect as I_Effect)
	return rule
