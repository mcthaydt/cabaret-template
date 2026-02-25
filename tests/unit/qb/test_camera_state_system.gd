extends BaseTest

const CAMERA_STATE_SYSTEM := preload("res://scripts/ecs/systems/s_camera_state_system.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")

const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")

const RULE_RESOURCE := preload("res://scripts/resources/qb/rs_rule.gd")
const CONDITION_CONSTANT := preload("res://scripts/resources/qb/conditions/rs_condition_constant.gd")
const CONDITION_ENTITY_TAG := preload("res://scripts/resources/qb/conditions/rs_condition_entity_tag.gd")
const EFFECT_SET_FIELD := preload("res://scripts/resources/qb/effects/rs_effect_set_field.gd")

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
	assert_eq(valid_rules.size(), 2)

	var rule_ids: Array[StringName] = []
	for rule_variant in valid_rules:
		if rule_variant == null or not (rule_variant is Object):
			continue
		rule_ids.append(rule_variant.get("rule_id") as StringName)
	assert_true(rule_ids.has(StringName("camera_shake")))
	assert_true(rule_ids.has(StringName("camera_zone_fov")))

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

	store.set_slice(StringName("camera"), {
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

	store.set_slice(StringName("camera"), {
		"in_fov_zone": true,
	})
	system.process_tick(0.25)

	assert_almost_eq(camera_manager.main_camera.fov, 75.0, 0.001)

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

	store.set_slice(StringName("camera"), {
		"in_fov_zone": true,
	})
	system.process_tick(1.0)
	assert_almost_eq(camera_manager.main_camera.fov, 60.0, 0.001)

	store.set_slice(StringName("camera"), {
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

	store.set_slice(StringName("camera"), {
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

	store_by_id.set_slice(StringName("camera"), {"in_fov_zone": true})
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

	store_by_tag.set_slice(StringName("camera"), {"in_fov_zone": true})
	system_by_tag.process_tick(1.0)
	assert_almost_eq(camera_manager_by_tag.main_camera.fov, 30.0, 0.001)

func _create_fixture(designer_rules: Array = [], entity_specs: Array = [], main_camera_fov: float = 90.0) -> Dictionary:
	var store := MOCK_STATE_STORE.new()
	autofree(store)
	store.set_slice(StringName("camera"), {
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

	var typed_rules: Array[Resource] = []
	for rule_variant in designer_rules:
		if rule_variant != null and rule_variant is Resource:
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

	entity.add_child(camera_state)
	ecs_manager.add_component_to_entity(entity, camera_state)
	ecs_manager.register_entity_id(entity.get_entity_id(), entity)

	return {
		"entity": entity,
		"camera_state": camera_state,
	}

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
	rule.conditions = [_make_constant_condition()]
	rule.effects = [effect]
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
	rule.conditions = [condition]
	rule.effects = [effect]
	return rule
