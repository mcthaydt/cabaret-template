@icon("res://resources/editor_icons/component.svg")
extends BaseECSComponent
class_name C_HealthComponent

## Health component holding mutable health state per entity.
## Systems queue damage/heal events on the component, S_HealthSystem
## applies them, handles regeneration, and triggers death sequences.

const COMPONENT_TYPE := StringName("C_HealthComponent")
const RS_HealthSettings := preload("res://scripts/ecs/resources/rs_health_settings.gd")
const EVENT_HEALTH_CHANGED := StringName("health_changed")
const EVENT_ENTITY_DEATH := StringName("entity_death")

@export var settings: RS_HealthSettings
@export_node_path("CharacterBody3D") var character_body_path: NodePath

var current_health: float = 0.0
var max_health: float = 0.0
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var time_since_last_damage: float = 0.0
var death_timer: float = 0.0

var _is_dead: bool = false
var _pending_instant_death: bool = false
var _pending_damage: Array[float] = []
var _pending_heals: Array[float] = []

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_HealthComponent missing settings; assign an RS_HealthSettings resource.")
		return false
	return true

func _on_required_settings_ready() -> void:
	max_health = max(settings.default_max_health, 1.0)
	current_health = max_health
	time_since_last_damage = settings.regen_delay
	is_invincible = false
	invincibility_timer = 0.0
	death_timer = 0.0
	_is_dead = false
	_pending_damage.clear()
	_pending_heals.clear()
	_pending_instant_death = false

func queue_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	_pending_damage.append(amount)

func queue_instant_death() -> void:
	_pending_instant_death = true

func queue_heal(amount: float) -> void:
	if amount <= 0.0:
		return
	_pending_heals.append(amount)

func dequeue_total_damage() -> float:
	if _pending_damage.is_empty():
		return 0.0
	var total := 0.0
	for amount in _pending_damage:
		total += max(amount, 0.0)
	_pending_damage.clear()
	return total

func dequeue_total_heal() -> float:
	if _pending_heals.is_empty():
		return 0.0
	var total := 0.0
	for amount in _pending_heals:
		total += max(amount, 0.0)
	_pending_heals.clear()
	return total

func consume_instant_death_flag() -> bool:
	if not _pending_instant_death:
		return false
	_pending_instant_death = false
	return true

func apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	var previous := current_health
	current_health = clampf(current_health - amount, 0.0, max_health)
	time_since_last_damage = 0.0
	if not is_equal_approx(previous, current_health):
		_publish_health_changed(previous, current_health)

func apply_heal(amount: float) -> void:
	if amount <= 0.0:
		return
	var previous := current_health
	current_health = clampf(current_health + amount, 0.0, max_health)
	if not is_equal_approx(previous, current_health):
		_publish_health_changed(previous, current_health)

func set_max_health(value: float) -> void:
	max_health = max(value, 1.0)
	current_health = clampf(current_health, 0.0, max_health)

func mark_dead() -> void:
	if _is_dead:
		return
	_is_dead = true
	var previous := current_health
	current_health = 0.0
	if not is_equal_approx(previous, current_health):
		_publish_health_changed(previous, current_health)
	_publish_death_event(previous)

func revive() -> void:
	_is_dead = false
	death_timer = 0.0

func is_dead() -> bool:
	return _is_dead

func get_character_body() -> CharacterBody3D:
	if character_body_path.is_empty():
		return null
	return get_node_or_null(character_body_path)

func set_character_body_path(path: NodePath) -> void:
	character_body_path = path

func get_current_health() -> float:
	return current_health

func get_max_health() -> float:
	return max_health

func reset_invincibility() -> void:
	is_invincible = false
	invincibility_timer = 0.0

func trigger_invincibility() -> void:
	if settings != null:
		is_invincible = true
		invincibility_timer = max(settings.invincibility_duration, 0.0)

func consume_invincibility(delta: float) -> void:
	if not is_invincible:
		return
	invincibility_timer = max(invincibility_timer - delta, 0.0)
	if invincibility_timer <= 0.0:
		is_invincible = false

func has_pending_damage() -> bool:
	return not _pending_damage.is_empty() or _pending_instant_death

func has_pending_heal() -> bool:
	return not _pending_heals.is_empty()

func _publish_health_changed(previous_health: float, new_health: float) -> void:
	U_ECSEventBus.publish(EVENT_HEALTH_CHANGED, {
		"entity_id": _get_entity_id(),
		"previous_health": previous_health,
		"new_health": new_health,
		"is_dead": _is_dead,
	})

func _publish_death_event(previous_health: float) -> void:
	U_ECSEventBus.publish(EVENT_ENTITY_DEATH, {
		"entity_id": _get_entity_id(),
		"previous_health": previous_health,
		"new_health": current_health,
		"is_dead": true,
	})

func _get_entity_id() -> StringName:
	var entity := ECS_UTILS.find_entity_root(self)
	if entity != null:
		return ECS_UTILS.get_entity_id(entity)

	var body := get_character_body()
	if body != null:
		return ECS_UTILS.get_entity_id(body)

	return StringName(String(name).to_lower())
