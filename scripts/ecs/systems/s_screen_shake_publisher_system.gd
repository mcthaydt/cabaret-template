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

## Magic numbers (Phase 4 will move to RS_ScreenShakeTuning)
const DAMAGE_MIN_TRAUMA := 0.3
const DAMAGE_MAX_TRAUMA := 0.6
const DAMAGE_MAX_VALUE := 100.0
const LANDING_THRESHOLD := 15.0
const LANDING_MAX_SPEED := 30.0
const LANDING_MIN_TRAUMA := 0.2
const LANDING_MAX_TRAUMA := 0.4
const DEATH_TRAUMA := 0.5

var _unsubscribe_health: Callable
var _unsubscribe_landed: Callable
var _unsubscribe_death: Callable

func on_configured() -> void:
	_unsubscribe_health = U_ECS_EVENT_BUS.subscribe(
		U_ECS_EVENT_NAMES.EVENT_HEALTH_CHANGED,
		_on_health_changed
	)
	_unsubscribe_landed = U_ECS_EVENT_BUS.subscribe(
		U_ECS_EVENT_NAMES.EVENT_ENTITY_LANDED,
		_on_landed
	)
	_unsubscribe_death = U_ECS_EVENT_BUS.subscribe(
		U_ECS_EVENT_NAMES.EVENT_ENTITY_DEATH,
		_on_death
	)

func _exit_tree() -> void:
	if _unsubscribe_health.is_valid():
		_unsubscribe_health.call()
	if _unsubscribe_landed.is_valid():
		_unsubscribe_landed.call()
	if _unsubscribe_death.is_valid():
		_unsubscribe_death.call()

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

	var damage_ratio: float = clampf(damage_amount / DAMAGE_MAX_VALUE, 0.0, 1.0)
	var trauma_amount: float = lerpf(DAMAGE_MIN_TRAUMA, DAMAGE_MAX_TRAUMA, damage_ratio)

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

	if fall_speed <= LANDING_THRESHOLD:
		return

	var speed_ratio: float = clampf(
		(fall_speed - LANDING_THRESHOLD) / (LANDING_MAX_SPEED - LANDING_THRESHOLD),
		0.0,
		1.0
	)
	var trauma_amount: float = lerpf(LANDING_MIN_TRAUMA, LANDING_MAX_TRAUMA, speed_ratio)

	var event := EVN_SCREEN_SHAKE_REQUEST.new(entity_id, trauma_amount, StringName("landing"))
	U_ECS_EVENT_BUS.publish_typed(event)

func _on_death(event_data: Dictionary) -> void:
	var payload: Dictionary = event_data.get("payload", {})
	var entity_id: StringName = StringName(str(payload.get("entity_id", "")))

	var event := EVN_SCREEN_SHAKE_REQUEST.new(entity_id, DEATH_TRAUMA, StringName("death"))
	U_ECS_EVENT_BUS.publish_typed(event)
