extends BaseTest

const CAMERA_RULE_MANAGER := preload("res://scripts/ecs/systems/s_camera_rule_manager.gd")
const QB_CONDITION := preload("res://scripts/resources/qb/rs_qb_condition.gd")
const QB_EFFECT := preload("res://scripts/resources/qb/rs_qb_effect.gd")
const QB_RULE := preload("res://scripts/resources/qb/rs_qb_rule_definition.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const C_CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")

func before_each() -> void:
	U_ECSEventBus.reset()

func test_default_rules_load_when_overrides_are_empty() -> void:
	var fixture: Dictionary = _create_system([], true)
	var system: Variant = fixture["system"]
	var rule_ids: Array[StringName] = system.get_registered_rule_ids()
	assert_eq(rule_ids.size(), 2)
	assert_true(rule_ids.has(StringName("camera_shake_rule")))
	assert_true(rule_ids.has(StringName("camera_zone_fov_rule")))

func test_shake_rule_adds_trauma_on_health_changed_event() -> void:
	var fixture: Dictionary = _create_system([_make_camera_shake_rule()])
	var ecs_manager: MockECSManager = fixture["ecs_manager"]
	var components: Dictionary = _register_camera_components(ecs_manager)
	var camera_state: Variant = components["camera_state"]

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_HEALTH_CHANGED, {
		"entity_id": StringName("player"),
		"previous_health": 100.0,
		"new_health": 60.0,
		"is_dead": false,
	})

	assert_almost_eq(camera_state.shake_trauma, 0.35, 0.001)

func test_shake_rule_add_clamps_to_max_trauma() -> void:
	var fixture: Dictionary = _create_system([_make_camera_shake_rule()])
	var ecs_manager: MockECSManager = fixture["ecs_manager"]
	var components: Dictionary = _register_camera_components(ecs_manager)
	var camera_state: Variant = components["camera_state"]
	camera_state.shake_trauma = 0.9

	U_ECSEventBus.publish(U_ECSEventNames.EVENT_HEALTH_CHANGED, {
		"entity_id": StringName("player"),
		"previous_health": 100.0,
		"new_health": 25.0,
		"is_dead": false,
	})

	assert_almost_eq(camera_state.shake_trauma, 1.0, 0.001)

func test_zone_rule_sets_target_fov_when_camera_zone_active() -> void:
	var fixture: Dictionary = _create_system([_make_camera_zone_rule(60.0)])
	var system: Variant = fixture["system"]
	var store: MockStateStore = fixture["store"]
	var ecs_manager: MockECSManager = fixture["ecs_manager"]
	var components: Dictionary = _register_camera_components(ecs_manager)
	var camera_state: Variant = components["camera_state"]

	store.set_slice(StringName("camera"), {"in_fov_zone": false})
	system.process_tick(0.016)
	assert_almost_eq(camera_state.target_fov, 75.0, 0.001)

	store.set_slice(StringName("camera"), {"in_fov_zone": true})
	system.process_tick(0.016)
	assert_almost_eq(camera_state.target_fov, 60.0, 0.001)

func test_camera_rule_manager_blends_camera_fov_toward_target() -> void:
	var fixture: Dictionary = _create_system([_make_camera_zone_rule(60.0)])
	var system: Variant = fixture["system"]
	var store: MockStateStore = fixture["store"]
	var camera_manager: MockCameraManager = fixture["camera_manager"]
	var ecs_manager: MockECSManager = fixture["ecs_manager"]
	_register_camera_components(ecs_manager)

	var camera := Camera3D.new()
	autofree(camera)
	camera.fov = 90.0
	camera_manager.main_camera = camera

	store.set_slice(StringName("camera"), {"in_fov_zone": true})
	system.process_tick(0.1)

	assert_true(camera.fov < 90.0)
	assert_true(camera.fov > 60.0)

func test_camera_rule_manager_applies_and_clears_shake_source() -> void:
	var fixture: Dictionary = _create_system([])
	var system: Variant = fixture["system"]
	var camera_manager: MockCameraManager = fixture["camera_manager"]
	var ecs_manager: MockECSManager = fixture["ecs_manager"]
	var components: Dictionary = _register_camera_components(ecs_manager)
	var camera_state: Variant = components["camera_state"]

	camera_state.shake_trauma = 1.0
	system.process_tick(0.1)

	assert_true(camera_manager.shake_sources.has(StringName("qb_camera_rule")))
	assert_true(camera_manager.apply_calls > 0)
	assert_true(float(camera_state.shake_trauma) < 1.0)

	camera_state.shake_trauma = 0.0
	system.process_tick(0.1)
	assert_false(camera_manager.shake_sources.has(StringName("qb_camera_rule")))

func _create_system(rules: Array = [], use_default_rules: bool = false) -> Dictionary:
	var store := MOCK_STATE_STORE.new()
	autofree(store)
	store.set_slice(StringName("camera"), {"in_fov_zone": false})

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var camera_manager := MOCK_CAMERA_MANAGER.new()
	autofree(camera_manager)

	var system := CAMERA_RULE_MANAGER.new()
	autofree(system)
	if not use_default_rules:
		system.rule_definitions = rules
	system.state_store = store
	system.ecs_manager = ecs_manager
	system.camera_manager = camera_manager
	system.configure(ecs_manager)

	return {
		"system": system,
		"store": store,
		"ecs_manager": ecs_manager,
		"camera_manager": camera_manager,
	}

func _register_camera_components(ecs_manager: MockECSManager) -> Dictionary:
	var entity := Node3D.new()
	entity.name = "E_Camera"
	autofree(entity)

	var camera_state := C_CAMERA_STATE_COMPONENT.new()
	entity.add_child(camera_state)
	autofree(camera_state)

	ecs_manager.add_component_to_entity(entity, camera_state)
	return {
		"entity": entity,
		"camera_state": camera_state,
	}

func _make_camera_shake_rule() -> Variant:
	var effect := QB_EFFECT.new()
	effect.effect_type = QB_EFFECT.EffectType.SET_COMPONENT_FIELD
	effect.target = "C_CameraStateComponent.shake_trauma"
	effect.payload = {
		"operation": StringName("add"),
		"value_type": QB_CONDITION.ValueType.FLOAT,
		"value_float": 0.35,
		"clamp_max": 1.0,
	}

	var rule := QB_RULE.new()
	rule.rule_id = StringName("camera_shake_damage")
	rule.trigger_mode = QB_RULE.TriggerMode.EVENT
	rule.trigger_event = U_ECSEventNames.EVENT_HEALTH_CHANGED
	rule.effects = [effect]
	return rule

func _make_camera_zone_rule(target_fov: float) -> Variant:
	var condition := QB_CONDITION.new()
	condition.source = QB_CONDITION.Source.REDUX
	condition.quality_path = "camera.in_fov_zone"
	condition.operator = QB_CONDITION.Operator.IS_TRUE

	var effect := QB_EFFECT.new()
	effect.effect_type = QB_EFFECT.EffectType.SET_COMPONENT_FIELD
	effect.target = "C_CameraStateComponent.target_fov"
	effect.payload = {
		"operation": StringName("set"),
		"value_type": QB_CONDITION.ValueType.FLOAT,
		"value_float": target_fov,
	}

	var rule := QB_RULE.new()
	rule.rule_id = StringName("camera_zone_fov")
	rule.trigger_mode = QB_RULE.TriggerMode.TICK
	rule.conditions = [condition]
	rule.effects = [effect]
	rule.requires_salience = false
	return rule
