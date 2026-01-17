@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_ScreenShakePublisherSystem

## Translates gameplay events into screen shake requests.
##
## Subscribes to: health_changed, entity_landed, entity_death
## Publishes: screen_shake_request

const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/ecs/u_ecs_event_names.gd")
const EVN_SCREEN_SHAKE_REQUEST := preload("res://scripts/ecs/events/evn_screen_shake_request.gd")
const DEFAULT_TUNING := preload("res://resources/vfx/rs_screen_shake_tuning.tres")

@export var tuning: Resource = null

var _event_unsubscribes: Array[Callable] = []

func on_configured() -> void:
	_event_unsubscribes.append(U_ECS_EVENT_BUS.subscribe(
		U_ECS_EVENT_NAMES.EVENT_HEALTH_CHANGED,
		_on_health_changed
	))
	_event_unsubscribes.append(U_ECS_EVENT_BUS.subscribe(
		U_ECS_EVENT_NAMES.EVENT_ENTITY_LANDED,
		_on_landed
	))
	_event_unsubscribes.append(U_ECS_EVENT_BUS.subscribe(
		U_ECS_EVENT_NAMES.EVENT_ENTITY_DEATH,
		_on_death
	))

func _exit_tree() -> void:
	for unsubscribe in _event_unsubscribes:
		if unsubscribe.is_valid():
			unsubscribe.call()
	_event_unsubscribes.clear()

func _get_tuning() -> Resource:
	if tuning != null:
		return tuning
	return DEFAULT_TUNING

func _on_health_changed(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var entity_id: StringName = StringName(str(payload.get("entity_id", "")))
	var is_dead: bool = bool(payload.get("is_dead", false))
	if is_dead:
		return

	var damage_amount: float = 0.0
	if payload.has("damage"):
		damage_amount = float(payload.get("damage", 0.0))
	else:
		var previous_health: float = float(payload.get("previous_health", 0.0))
		var new_health: float = float(payload.get("new_health", previous_health))
		damage_amount = maxf(previous_health - new_health, 0.0)

	if damage_amount <= 0.0:
		return

	var trauma_amount: float = float(_get_tuning().calculate_damage_trauma(damage_amount))
	if trauma_amount <= 0.0:
		return

	var event := EVN_SCREEN_SHAKE_REQUEST.new(entity_id, trauma_amount, StringName("damage"))
	U_ECS_EVENT_BUS.publish_typed(event)

func _on_landed(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var entity_id: StringName = StringName(str(payload.get("entity_id", "")))

	var fall_speed: float = 0.0
	if payload.has("fall_speed"):
		fall_speed = float(payload.get("fall_speed", 0.0))
	else:
		fall_speed = absf(float(payload.get("vertical_velocity", 0.0)))

	var trauma_amount: float = float(_get_tuning().calculate_landing_trauma(fall_speed))
	if trauma_amount <= 0.0:
		return

	var event := EVN_SCREEN_SHAKE_REQUEST.new(entity_id, trauma_amount, StringName("landing"))
	U_ECS_EVENT_BUS.publish_typed(event)

func _on_death(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var entity_id: StringName = StringName(str(payload.get("entity_id", "")))

	var trauma_amount: float = float(_get_tuning().death_trauma)
	var event := EVN_SCREEN_SHAKE_REQUEST.new(entity_id, trauma_amount, StringName("death"))
	U_ECS_EVENT_BUS.publish_typed(event)
