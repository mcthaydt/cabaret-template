extends BaseTest

const QB_CONDITION := preload("res://scripts/resources/qb/rs_qb_condition.gd")
const QB_EFFECT := preload("res://scripts/resources/qb/rs_qb_effect.gd")
const QB_EFFECT_EXECUTOR := preload("res://scripts/utils/qb/u_qb_effect_executor.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")

class MockStatsComponent extends RefCounted:
	var health: float = 10.0
	var count: int = 2
	var label: String = "base"

func before_each() -> void:
	U_ECSEventBus.reset()

func _make_effect(effect_type: int, target: String, payload: Dictionary = {}) -> Variant:
	var effect: Variant = QB_EFFECT.new()
	effect.effect_type = effect_type
	effect.target = target
	effect.payload = payload.duplicate(true)
	return effect

func test_dispatch_action_effect_dispatches_to_state_store() -> void:
	var store := MOCK_STATE_STORE.new()
	add_child(store)
	autofree(store)
	var effect: Variant = _make_effect(
		QB_EFFECT.EffectType.DISPATCH_ACTION,
		"gameplay/set_paused",
		{"paused": true}
	)
	var context: Dictionary = {
		"state_store": store
	}

	QB_EFFECT_EXECUTOR.execute_effect(effect, context)

	var actions: Array[Dictionary] = store.get_dispatched_actions()
	assert_eq(actions.size(), 1)
	if actions.is_empty():
		return
	assert_eq(actions[0].get("type"), StringName("gameplay/set_paused"))
	assert_eq(actions[0].get("payload"), {"paused": true})

func test_publish_event_effect_merges_context_entity_id_and_event_payload() -> void:
	var captured_payloads: Array = []
	var unsubscribe: Callable = U_ECSEventBus.subscribe(
		StringName("test_rule_event"),
		func(event_data: Variant) -> void:
			if event_data is Dictionary:
				var event_dict: Dictionary = event_data as Dictionary
				captured_payloads.append(event_dict.get("payload", {}))
	)

	var effect: Variant = _make_effect(
		QB_EFFECT.EffectType.PUBLISH_EVENT,
		"test_rule_event",
		{"source": "rule"}
	)
	var context: Dictionary = {
		"entity_id": StringName("player"),
		"event_payload": {
			"damage": 25.0,
			"source": "original_event"
		}
	}

	QB_EFFECT_EXECUTOR.execute_effect(effect, context)
	unsubscribe.call()

	assert_eq(captured_payloads.size(), 1)
	if captured_payloads.is_empty():
		return
	var payload: Dictionary = captured_payloads[0]
	assert_eq(payload.get("entity_id"), StringName("player"))
	assert_eq(payload.get("damage"), 25.0)
	assert_eq(payload.get("source"), "rule")

func test_set_component_field_effect_supports_set_operation() -> void:
	var component := MockStatsComponent.new()
	var effect: Variant = _make_effect(
		QB_EFFECT.EffectType.SET_COMPONENT_FIELD,
		"C_StatsComponent.health",
		{
			"operation": StringName("set"),
			"value_type": QB_CONDITION.ValueType.FLOAT,
			"value_float": 27.5
		}
	)
	var context: Dictionary = {
		"components": {
			"C_StatsComponent": component
		}
	}

	QB_EFFECT_EXECUTOR.execute_effect(effect, context)
	assert_eq(component.health, 27.5)

func test_set_component_field_effect_supports_add_with_clamp() -> void:
	var component := MockStatsComponent.new()
	var effect: Variant = _make_effect(
		QB_EFFECT.EffectType.SET_COMPONENT_FIELD,
		"C_StatsComponent.health",
		{
			"operation": StringName("add"),
			"value_type": QB_CONDITION.ValueType.FLOAT,
			"value_float": 25.0,
			"clamp_max": 20.0
		}
	)
	var context: Dictionary = {
		"components": {
			"C_StatsComponent": component
		}
	}

	QB_EFFECT_EXECUTOR.execute_effect(effect, context)
	assert_eq(component.health, 20.0)

func test_set_quality_effect_writes_to_context_dictionary() -> void:
	var effect: Variant = _make_effect(
		QB_EFFECT.EffectType.SET_QUALITY,
		"is_dead",
		{
			"value_type": QB_CONDITION.ValueType.BOOL,
			"value_bool": true
		}
	)
	var context: Dictionary = {}

	QB_EFFECT_EXECUTOR.execute_effect(effect, context)
	assert_eq(context.get("is_dead"), true)

func test_set_quality_effect_supports_string_value_type_name() -> void:
	var effect: Variant = _make_effect(
		QB_EFFECT.EffectType.SET_QUALITY,
		"is_gameplay_active",
		{
			"value_type": "BOOL",
			"value_bool": false
		}
	)
	var context: Dictionary = {}

	QB_EFFECT_EXECUTOR.execute_effect(effect, context)
	assert_eq(context.get("is_gameplay_active"), false)

func test_execute_effects_processes_multiple_effects() -> void:
	var component := MockStatsComponent.new()
	var context: Dictionary = {
		"components": {
			"C_StatsComponent": component
		}
	}
	var effects: Array = [
		_make_effect(
			QB_EFFECT.EffectType.SET_COMPONENT_FIELD,
			"C_StatsComponent.count",
			{
				"operation": StringName("add"),
				"value_type": QB_CONDITION.ValueType.INT,
				"value_int": 3
			}
		),
		_make_effect(
			QB_EFFECT.EffectType.SET_QUALITY,
			"is_gameplay_active",
			{
				"value_type": QB_CONDITION.ValueType.BOOL,
				"value_bool": false
			}
		)
	]

	QB_EFFECT_EXECUTOR.execute_effects(effects, context)
	assert_eq(component.count, 5)
	assert_eq(context.get("is_gameplay_active"), false)
