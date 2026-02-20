extends BaseTest

const CHARACTER_RULE_MANAGER := preload("res://scripts/ecs/systems/s_character_rule_manager.gd")
const QB_CONDITION := preload("res://scripts/resources/qb/rs_qb_condition.gd")
const QB_EFFECT := preload("res://scripts/resources/qb/rs_qb_effect.gd")
const QB_RULE := preload("res://scripts/resources/qb/rs_qb_rule_definition.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const C_CHARACTER_STATE_COMPONENT := preload("res://scripts/ecs/components/c_character_state_component.gd")
const C_HEALTH_COMPONENT := preload("res://scripts/ecs/components/c_health_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_SPAWN_STATE_COMPONENT := preload("res://scripts/ecs/components/c_spawn_state_component.gd")

func before_each() -> void:
	U_ECSEventBus.reset()

func test_brain_data_population_reads_components_and_state() -> void:
	var setup := _create_system([])
	var system = setup["system"]
	var store: MockStateStore = setup["store"]
	var ecs_manager: MockECSManager = setup["ecs_manager"]
	var components := _register_character_components(ecs_manager)

	store.set_slice(StringName("gameplay"), {"paused": false})
	store.set_slice(StringName("navigation"), {"shell": "gameplay"})
	store.set_slice(StringName("scene"), {"is_transitioning": false})

	var body: CharacterBody3D = components["body"]
	body.velocity = Vector3(4.0, 3.0, 0.0)

	var input_component: C_InputComponent = components["input_component"]
	input_component.move_vector = Vector2(1.0, 0.0)

	var health_component: C_HealthComponent = components["health_component"]
	health_component.set_max_health(200.0)
	health_component.current_health = 50.0
	health_component.is_invincible = true

	system.process_tick(0.016)

	var character_state = components["character_state"]
	assert_true(character_state.is_gameplay_active)
	assert_false(character_state.is_grounded)
	assert_true(character_state.is_moving)
	assert_false(character_state.is_spawn_frozen)
	assert_false(character_state.is_dead)
	assert_true(character_state.is_invincible)
	assert_almost_eq(character_state.health_percent, 0.25, 0.001)
	assert_eq(character_state.vertical_state, C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_RISING)
	assert_true(character_state.has_input)

func test_pause_gate_rules_apply_all_or_paths() -> void:
	var rules: Array = [
		_make_pause_paused_rule(),
		_make_pause_shell_rule(),
		_make_pause_transitioning_rule(),
	]
	var setup := _create_system(rules)
	var system = setup["system"]
	var store: MockStateStore = setup["store"]
	var ecs_manager: MockECSManager = setup["ecs_manager"]
	var components := _register_character_components(ecs_manager)
	var character_state = components["character_state"]

	_set_gate_state(store, false, "gameplay", false)
	system.process_tick(0.016)
	assert_true(character_state.is_gameplay_active)

	_set_gate_state(store, true, "gameplay", false)
	system.process_tick(0.016)
	assert_false(character_state.is_gameplay_active)

	_set_gate_state(store, false, "menu", false)
	system.process_tick(0.016)
	assert_false(character_state.is_gameplay_active)

	_set_gate_state(store, false, "gameplay", true)
	system.process_tick(0.016)
	assert_false(character_state.is_gameplay_active)

func test_spawn_freeze_rule_sets_and_clears_brain_flag() -> void:
	var setup := _create_system([_make_spawn_freeze_rule()])
	var system = setup["system"]
	var ecs_manager: MockECSManager = setup["ecs_manager"]
	var components := _register_character_components(ecs_manager)
	var character_state = components["character_state"]
	var spawn_state: C_SpawnStateComponent = components["spawn_component"]

	spawn_state.is_physics_frozen = true
	system.process_tick(0.016)
	assert_true(character_state.is_spawn_frozen)

	spawn_state.is_physics_frozen = false
	system.process_tick(0.016)
	assert_false(character_state.is_spawn_frozen)

func test_spawn_and_death_brain_flags_remain_default_without_rules() -> void:
	var setup := _create_system([_make_pause_paused_rule()])
	var system = setup["system"]
	var ecs_manager: MockECSManager = setup["ecs_manager"]
	var components := _register_character_components(ecs_manager)
	var character_state = components["character_state"]
	var spawn_state: C_SpawnStateComponent = components["spawn_component"]
	var health_component: C_HealthComponent = components["health_component"]

	spawn_state.is_physics_frozen = true
	health_component.set("_is_dead", true)
	system.process_tick(0.016)

	assert_false(character_state.is_spawn_frozen)
	assert_false(character_state.is_dead)

func test_death_sync_rule_sets_and_clears_brain_flag() -> void:
	var setup := _create_system([_make_death_sync_rule()])
	var system = setup["system"]
	var ecs_manager: MockECSManager = setup["ecs_manager"]
	var components := _register_character_components(ecs_manager)
	var character_state = components["character_state"]
	var health_component: C_HealthComponent = components["health_component"]

	health_component.set("_is_dead", true)
	system.process_tick(0.016)
	assert_true(character_state.is_dead)

	health_component.set("_is_dead", false)
	system.process_tick(0.016)
	assert_false(character_state.is_dead)

func test_defaults_reset_each_tick_after_pause_gate_clears() -> void:
	var rules: Array = [
		_make_pause_paused_rule(),
		_make_pause_shell_rule(),
		_make_pause_transitioning_rule(),
	]
	var setup := _create_system(rules)
	var system = setup["system"]
	var store: MockStateStore = setup["store"]
	var ecs_manager: MockECSManager = setup["ecs_manager"]
	var components := _register_character_components(ecs_manager)
	var character_state = components["character_state"]

	_set_gate_state(store, true, "gameplay", false)
	system.process_tick(0.016)
	assert_false(character_state.is_gameplay_active)

	_set_gate_state(store, false, "gameplay", false)
	system.process_tick(0.016)
	assert_true(character_state.is_gameplay_active)

func _create_system(rules: Array) -> Dictionary:
	var store := MOCK_STATE_STORE.new()
	autofree(store)
	_set_gate_state(store, false, "gameplay", false)

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var system := CHARACTER_RULE_MANAGER.new()
	autofree(system)
	system.rule_definitions = rules
	system.state_store = store
	system.ecs_manager = ecs_manager
	system.configure(ecs_manager)

	return {
		"system": system,
		"store": store,
		"ecs_manager": ecs_manager,
	}

func _register_character_components(ecs_manager: MockECSManager) -> Dictionary:
	var entity := Node3D.new()
	entity.name = "E_Player"
	autofree(entity)

	var body := CharacterBody3D.new()
	body.name = "Body"
	entity.add_child(body)
	autofree(body)

	var character_state := C_CHARACTER_STATE_COMPONENT.new()
	entity.add_child(character_state)
	autofree(character_state)

	var movement_component := C_MOVEMENT_COMPONENT.new()
	entity.add_child(movement_component)
	autofree(movement_component)

	var input_component := C_INPUT_COMPONENT.new()
	entity.add_child(input_component)
	autofree(input_component)

	var spawn_component := C_SPAWN_STATE_COMPONENT.new()
	entity.add_child(spawn_component)
	autofree(spawn_component)

	var health_component := C_HEALTH_COMPONENT.new()
	entity.add_child(health_component)
	autofree(health_component)

	ecs_manager.add_component_to_entity(entity, character_state)
	ecs_manager.add_component_to_entity(entity, movement_component)
	ecs_manager.add_component_to_entity(entity, input_component)
	ecs_manager.add_component_to_entity(entity, spawn_component)
	ecs_manager.add_component_to_entity(entity, health_component)

	return {
		"entity": entity,
		"body": body,
		"character_state": character_state,
		"movement_component": movement_component,
		"input_component": input_component,
		"spawn_component": spawn_component,
		"health_component": health_component,
	}

func _set_gate_state(store: MockStateStore, paused: bool, shell: String, transitioning: bool) -> void:
	store.set_slice(StringName("gameplay"), {
		"paused": paused,
	})
	store.set_slice(StringName("navigation"), {
		"shell": shell,
	})
	store.set_slice(StringName("scene"), {
		"is_transitioning": transitioning,
	})

func _make_pause_paused_rule() -> Variant:
	var condition := QB_CONDITION.new()
	condition.source = QB_CONDITION.Source.REDUX
	condition.quality_path = "gameplay.paused"
	condition.operator = QB_CONDITION.Operator.IS_TRUE

	return _make_set_quality_rule(
		StringName("pause_gate_paused"),
		condition,
		"is_gameplay_active",
		false
	)

func _make_pause_shell_rule() -> Variant:
	var condition := QB_CONDITION.new()
	condition.source = QB_CONDITION.Source.REDUX
	condition.quality_path = "navigation.shell"
	condition.operator = QB_CONDITION.Operator.NOT_EQUALS
	condition.value_type = QB_CONDITION.ValueType.STRING
	condition.value_string = "gameplay"

	return _make_set_quality_rule(
		StringName("pause_gate_shell"),
		condition,
		"is_gameplay_active",
		false
	)

func _make_pause_transitioning_rule() -> Variant:
	var condition := QB_CONDITION.new()
	condition.source = QB_CONDITION.Source.REDUX
	condition.quality_path = "scene.is_transitioning"
	condition.operator = QB_CONDITION.Operator.IS_TRUE

	return _make_set_quality_rule(
		StringName("pause_gate_transitioning"),
		condition,
		"is_gameplay_active",
		false
	)

func _make_spawn_freeze_rule() -> Variant:
	var condition := QB_CONDITION.new()
	condition.source = QB_CONDITION.Source.COMPONENT
	condition.quality_path = "C_SpawnStateComponent.is_physics_frozen"
	condition.operator = QB_CONDITION.Operator.IS_TRUE

	return _make_set_quality_rule(
		StringName("spawn_freeze"),
		condition,
		"is_spawn_frozen",
		true
	)

func _make_death_sync_rule() -> Variant:
	var condition := QB_CONDITION.new()
	condition.source = QB_CONDITION.Source.COMPONENT
	condition.quality_path = "C_HealthComponent.is_dead"
	condition.operator = QB_CONDITION.Operator.IS_TRUE

	return _make_set_quality_rule(
		StringName("death_sync"),
		condition,
		"is_dead",
		true
	)

func _make_set_quality_rule(
	rule_id: StringName,
	condition: Variant,
	target: String,
	value: bool
) -> Variant:
	var effect := QB_EFFECT.new()
	effect.effect_type = QB_EFFECT.EffectType.SET_QUALITY
	effect.target = target
	effect.payload = {
		"value_type": QB_CONDITION.ValueType.BOOL,
		"value_bool": value,
	}

	var rule := QB_RULE.new()
	rule.rule_id = rule_id
	rule.conditions = [condition]
	rule.effects = [effect]
	rule.trigger_mode = QB_RULE.TriggerMode.TICK
	rule.requires_salience = false
	return rule
