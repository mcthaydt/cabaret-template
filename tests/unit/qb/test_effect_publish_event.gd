extends BaseTest

const EFFECT_PUBLISH_EVENT := preload("res://scripts/resources/qb/effects/rs_effect_publish_event.gd")
const ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

func before_each() -> void:
	ECS_EVENT_BUS.reset()

func after_each() -> void:
	ECS_EVENT_BUS.reset()

func test_publishes_event_with_correct_name_and_payload() -> void:
	var effect: Variant = EFFECT_PUBLISH_EVENT.new()
	effect.event_name = StringName("checkpoint_activation_requested")
	effect.payload = {
		"checkpoint": "cp_lobby"
	}

	effect.execute({})

	var history: Array = ECS_EVENT_BUS.get_event_history()
	assert_eq(history.size(), 1)
	var published_event: Dictionary = history[0]
	assert_eq(published_event.get("name", StringName()), StringName("checkpoint_activation_requested"))

	var payload: Dictionary = published_event.get("payload", {})
	assert_eq(payload.get("checkpoint", ""), "cp_lobby")

func test_entity_id_is_injected_when_enabled() -> void:
	var effect: Variant = EFFECT_PUBLISH_EVENT.new()
	effect.event_name = StringName("victory_execution_requested")
	effect.inject_entity_id = true
	effect.payload = {
		"area_id": "bar"
	}

	var context: Dictionary = {
		"entity_id": StringName("player")
	}
	effect.execute(context)

	var history: Array = ECS_EVENT_BUS.get_event_history()
	var published_event: Dictionary = history[0]
	var payload: Dictionary = published_event.get("payload", {})
	assert_eq(payload.get("entity_id", StringName()), StringName("player"))

func test_entity_id_is_not_injected_when_disabled() -> void:
	var effect: Variant = EFFECT_PUBLISH_EVENT.new()
	effect.event_name = StringName("victory_execution_requested")
	effect.inject_entity_id = false
	effect.payload = {
		"area_id": "bar"
	}

	var context: Dictionary = {
		"entity_id": StringName("player")
	}
	effect.execute(context)

	var history: Array = ECS_EVENT_BUS.get_event_history()
	var published_event: Dictionary = history[0]
	var payload: Dictionary = published_event.get("payload", {})
	assert_false(payload.has("entity_id"))

func test_entity_id_is_injected_when_context_uses_string_name_key() -> void:
	var effect: Variant = EFFECT_PUBLISH_EVENT.new()
	effect.event_name = StringName("checkpoint_activation_requested")
	effect.inject_entity_id = true
	effect.payload = {
		"checkpoint": "cp_lobby"
	}

	var context: Dictionary = {
		StringName("entity_id"): StringName("player")
	}
	effect.execute(context)

	var history: Array = ECS_EVENT_BUS.get_event_history()
	assert_eq(history.size(), 1)
	var published_event: Dictionary = history[0]
	var payload: Dictionary = published_event.get("payload", {})
	assert_eq(payload.get("entity_id", StringName()), StringName("player"))
