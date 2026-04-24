extends BaseTest

const CHARACTER_STATE_SYSTEM := preload("res://scripts/ecs/systems/s_character_state_system.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")

const RULE_RESOURCE := preload("res://scripts/resources/qb/rs_rule.gd")
const CONDITION_REDUX_FIELD := preload("res://scripts/resources/qb/conditions/rs_condition_redux_field.gd")
const CONDITION_COMPONENT_FIELD := preload("res://scripts/resources/qb/conditions/rs_condition_component_field.gd")
const CONDITION_CONSTANT := preload("res://scripts/resources/qb/conditions/rs_condition_constant.gd")
const EFFECT_SET_CONTEXT_VALUE := preload("res://scripts/resources/qb/effects/rs_effect_set_context_value.gd")
const EFFECT_DISPATCH_ACTION := preload("res://scripts/resources/qb/effects/rs_effect_dispatch_action.gd")

const I_CONDITION := preload("res://scripts/core/interfaces/i_condition.gd")
const I_EFFECT := preload("res://scripts/core/interfaces/i_effect.gd")

const C_CHARACTER_STATE_COMPONENT := preload("res://scripts/ecs/components/c_character_state_component.gd")
const C_FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")
const C_HEALTH_COMPONENT := preload("res://scripts/ecs/components/c_health_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_SPAWN_STATE_COMPONENT := preload("res://scripts/ecs/components/c_spawn_state_component.gd")

func before_each() -> void:
	U_ECSEventBus.reset()

func test_brain_data_defaults_reset_each_tick() -> void:
	var fixture: Dictionary = _create_fixture()
	var system: Variant = fixture["system"]
	var store: MockStateStore = fixture["store"] as MockStateStore
	var character_state: C_CharacterStateComponent = fixture["character_state"] as C_CharacterStateComponent

	_set_gate_state(store, true, "gameplay", false)
	system.process_tick(0.016)
	assert_false(character_state.is_gameplay_active)

	_set_gate_state(store, false, "gameplay", false)
	system.process_tick(0.016)
	assert_true(character_state.is_gameplay_active)
	assert_false(character_state.is_spawn_frozen)
	assert_false(character_state.is_dead)

func test_pause_gate_paused_sets_is_gameplay_active_false() -> void:
	var fixture: Dictionary = _create_fixture()
	var system: Variant = fixture["system"]
	var store: MockStateStore = fixture["store"] as MockStateStore
	var character_state: C_CharacterStateComponent = fixture["character_state"] as C_CharacterStateComponent

	_set_gate_state(store, true, "gameplay", false)
	system.process_tick(0.016)

	assert_false(character_state.is_gameplay_active)

func test_pause_gate_shell_sets_is_gameplay_active_false_when_not_gameplay_shell() -> void:
	var fixture: Dictionary = _create_fixture()
	var system: Variant = fixture["system"]
	var store: MockStateStore = fixture["store"] as MockStateStore
	var character_state: C_CharacterStateComponent = fixture["character_state"] as C_CharacterStateComponent

	_set_gate_state(store, false, "menu", false)
	system.process_tick(0.016)

	assert_false(character_state.is_gameplay_active)

func test_pause_gate_transitioning_sets_is_gameplay_active_false_when_transitioning() -> void:
	var fixture: Dictionary = _create_fixture()
	var system: Variant = fixture["system"]
	var store: MockStateStore = fixture["store"] as MockStateStore
	var character_state: C_CharacterStateComponent = fixture["character_state"] as C_CharacterStateComponent

	_set_gate_state(store, false, "gameplay", true)
	system.process_tick(0.016)

	assert_false(character_state.is_gameplay_active)

func test_pause_gates_compete_in_decision_group_only_one_winner_fires() -> void:
	var designer_rules: Array = [
		_make_dispatch_rule(StringName("pause_gate_a"), StringName("action_a"), 0, StringName("pause_gate")),
		_make_dispatch_rule(StringName("pause_gate_b"), StringName("action_b"), 10, StringName("pause_gate")),
	]
	var fixture: Dictionary = _create_fixture(designer_rules)
	var system: Variant = fixture["system"]
	var store: MockStateStore = fixture["store"] as MockStateStore

	system.process_tick(0.016)

	var actions: Array[Dictionary] = store.get_dispatched_actions()
	assert_eq(actions.size(), 1, "Only one rule in the decision group should execute")
	if actions.is_empty():
		return
	assert_eq(actions[0].get("type"), StringName("action_b"))

func test_spawn_freeze_sets_is_spawn_frozen_true_when_component_reports_frozen() -> void:
	var fixture: Dictionary = _create_fixture()
	var system: Variant = fixture["system"]
	var character_state: C_CharacterStateComponent = fixture["character_state"] as C_CharacterStateComponent
	var spawn_component: C_SpawnStateComponent = fixture["spawn_component"] as C_SpawnStateComponent

	spawn_component.is_physics_frozen = true
	system.process_tick(0.016)

	assert_true(character_state.is_spawn_frozen)

func test_spawn_freeze_clears_when_component_reports_unfrozen() -> void:
	var fixture: Dictionary = _create_fixture()
	var system: Variant = fixture["system"]
	var character_state: C_CharacterStateComponent = fixture["character_state"] as C_CharacterStateComponent
	var spawn_component: C_SpawnStateComponent = fixture["spawn_component"] as C_SpawnStateComponent

	spawn_component.is_physics_frozen = true
	system.process_tick(0.016)
	assert_true(character_state.is_spawn_frozen)

	spawn_component.is_physics_frozen = false
	system.process_tick(0.016)
	assert_false(character_state.is_spawn_frozen)

func test_death_sync_sets_is_dead_true_when_health_component_reports_dead() -> void:
	var fixture: Dictionary = _create_fixture()
	var system: Variant = fixture["system"]
	var character_state: C_CharacterStateComponent = fixture["character_state"] as C_CharacterStateComponent
	var health_component: C_HealthComponent = fixture["health_component"] as C_HealthComponent

	health_component.set("_is_dead", true)
	system.process_tick(0.016)

	assert_true(character_state.is_dead)

func test_death_sync_clears_when_health_component_reports_alive() -> void:
	var fixture: Dictionary = _create_fixture()
	var system: Variant = fixture["system"]
	var character_state: C_CharacterStateComponent = fixture["character_state"] as C_CharacterStateComponent
	var health_component: C_HealthComponent = fixture["health_component"] as C_HealthComponent

	health_component.set("_is_dead", true)
	system.process_tick(0.016)
	assert_true(character_state.is_dead)

	health_component.set("_is_dead", false)
	system.process_tick(0.016)
	assert_false(character_state.is_dead)

func test_health_percent_populated_from_health_component() -> void:
	var fixture: Dictionary = _create_fixture()
	var system: Variant = fixture["system"]
	var character_state: C_CharacterStateComponent = fixture["character_state"] as C_CharacterStateComponent
	var health_component: C_HealthComponent = fixture["health_component"] as C_HealthComponent

	health_component.set_max_health(200.0)
	health_component.current_health = 50.0
	system.process_tick(0.016)

	assert_almost_eq(character_state.health_percent, 0.25, 0.001)

func test_is_grounded_populated_from_character_body_and_floating_state() -> void:
	var fixture: Dictionary = _create_fixture()
	var system: Variant = fixture["system"]
	var character_state: C_CharacterStateComponent = fixture["character_state"] as C_CharacterStateComponent
	var floating_component: C_FloatingComponent = fixture["floating_component"] as C_FloatingComponent

	floating_component.grounded_stable = true
	system.process_tick(0.016)
	assert_true(character_state.is_grounded)

	floating_component.grounded_stable = false
	floating_component.is_supported = false
	system.process_tick(0.016)
	assert_false(character_state.is_grounded)

func test_is_moving_populated_from_velocity_threshold() -> void:
	var fixture: Dictionary = _create_fixture()
	var system: Variant = fixture["system"]
	var character_state: C_CharacterStateComponent = fixture["character_state"] as C_CharacterStateComponent
	var body: CharacterBody3D = fixture["body"] as CharacterBody3D

	body.velocity = Vector3(0.2, 0.0, 0.0)
	system.process_tick(0.016)
	assert_true(character_state.is_moving)

	body.velocity = Vector3(0.05, 0.0, 0.0)
	system.process_tick(0.016)
	assert_false(character_state.is_moving)

func test_designer_rules_via_export_are_evaluated_alongside_defaults() -> void:
	var designer_rules: Array = [
		_make_set_context_rule(
			StringName("designer_set_invincible"),
			_make_constant_condition(),
			StringName("is_invincible"),
			true
		)
	]
	var fixture: Dictionary = _create_fixture(designer_rules)
	var system: Variant = fixture["system"]
	var store: MockStateStore = fixture["store"] as MockStateStore
	var character_state: C_CharacterStateComponent = fixture["character_state"] as C_CharacterStateComponent

	_set_gate_state(store, true, "gameplay", false)
	system.process_tick(0.016)

	assert_false(character_state.is_gameplay_active, "Default pause-gate rules should still execute")
	assert_true(character_state.is_invincible, "Designer rule should execute alongside defaults")

func _create_fixture(designer_rules: Array = []) -> Dictionary:
	var store := MOCK_STATE_STORE.new()
	autofree(store)
	_set_gate_state(store, false, "gameplay", false)

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var system := CHARACTER_STATE_SYSTEM.new()
	autofree(system)
	system.state_store = store
	system.ecs_manager = ecs_manager
	var typed_rules: Array[RS_Rule] = []
	for rule_variant in designer_rules:
		if rule_variant is RS_Rule:
			typed_rules.append(rule_variant)
	system.rules = typed_rules
	system.configure(ecs_manager)

	var components: Dictionary = _register_character_components(ecs_manager)
	components["system"] = system
	components["store"] = store
	components["ecs_manager"] = ecs_manager
	return components

func _register_character_components(ecs_manager: MockECSManager) -> Dictionary:
	var entity := Node3D.new()
	entity.name = "E_Player"
	autofree(entity)

	var body := CharacterBody3D.new()
	body.name = "Body"
	entity.add_child(body)
	autofree(body)

	var character_state := C_CharacterStateComponent.new()
	entity.add_child(character_state)
	autofree(character_state)

	var movement_component := C_MovementComponent.new()
	entity.add_child(movement_component)
	autofree(movement_component)

	var floating_component := C_FloatingComponent.new()
	floating_component.character_body_path = NodePath("../Body")
	entity.add_child(floating_component)
	autofree(floating_component)

	var input_component := C_InputComponent.new()
	entity.add_child(input_component)
	autofree(input_component)

	var spawn_component := C_SpawnStateComponent.new()
	spawn_component.character_body_path = NodePath("../Body")
	entity.add_child(spawn_component)
	autofree(spawn_component)

	var health_component := C_HealthComponent.new()
	health_component.character_body_path = NodePath("../Body")
	entity.add_child(health_component)
	autofree(health_component)

	ecs_manager.add_component_to_entity(entity, character_state)
	ecs_manager.add_component_to_entity(entity, movement_component)
	ecs_manager.add_component_to_entity(entity, floating_component)
	ecs_manager.add_component_to_entity(entity, input_component)
	ecs_manager.add_component_to_entity(entity, spawn_component)
	ecs_manager.add_component_to_entity(entity, health_component)

	return {
		"entity": entity,
		"body": body,
		"character_state": character_state,
		"movement_component": movement_component,
		"floating_component": floating_component,
		"input_component": input_component,
		"spawn_component": spawn_component,
		"health_component": health_component,
	}

func _set_gate_state(store: MockStateStore, paused: bool, shell: String, transitioning: bool) -> void:
	store.set_slice(StringName("time"), {
		"is_paused": paused,
	})
	store.set_slice(StringName("navigation"), {
		"shell": shell,
	})
	store.set_slice(StringName("scene"), {
		"is_transitioning": transitioning,
	})

func _make_redux_condition(state_path: String, match_mode: String, match_value: String) -> Variant:
	var condition := CONDITION_REDUX_FIELD.new()
	condition.state_path = state_path
	condition.match_mode = match_mode
	condition.match_value_string = match_value
	return condition

func _make_constant_condition() -> Variant:
	var condition := CONDITION_CONSTANT.new()
	condition.score = 1.0
	return condition

func _make_set_context_rule(
	rule_id: StringName,
	condition: Variant,
	context_key: StringName,
	bool_value: bool
) -> Variant:
	var effect := EFFECT_SET_CONTEXT_VALUE.new()
	effect.context_key = context_key
	effect.value_type = "bool"
	effect.bool_value = bool_value

	var rule := RULE_RESOURCE.new()
	rule.rule_id = rule_id
	rule.conditions.clear()
	rule.conditions.append(condition as I_Condition)
	rule.effects.clear()
	rule.effects.append(effect as I_Effect)
	return rule

func _make_dispatch_rule(rule_id: StringName, action_type: StringName, priority: int, group: StringName) -> Variant:
	var effect := EFFECT_DISPATCH_ACTION.new()
	effect.action_type = action_type
	effect.payload = {}

	var rule := RULE_RESOURCE.new()
	rule.rule_id = rule_id
	rule.priority = priority
	rule.decision_group = group
	rule.conditions.clear()
	rule.conditions.append(_make_constant_condition() as I_Condition)
	rule.effects.clear()
	rule.effects.append(effect as I_Effect)
	return rule
