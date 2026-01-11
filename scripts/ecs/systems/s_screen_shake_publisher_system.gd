@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_ScreenShakePublisherSystem

## Translates raw gameplay events into VFX screen shake requests.
## Performs player-only gating at the publisher level.
##
## Subscribes to: health_changed, entity_landed, entity_death
## Publishes: screen_shake_request

const EVENT_HEALTH_CHANGED := StringName("health_changed")
const EVENT_ENTITY_LANDED := StringName("entity_landed")
const EVENT_ENTITY_DEATH := StringName("entity_death")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const Evn_ScreenShakeRequest := preload("res://scripts/ecs/events/evn_screen_shake_request.gd")

## Injected state store (for testing)
@export var state_store: I_StateStore = null

## Tuning resource for trauma calculations
@export var tuning: Resource = null

var _state_store: I_StateStore = null
var _event_unsubscribes: Array[Callable] = []
var _player_entity_id: StringName = StringName("")

func on_configured() -> void:
	_subscribe_events()
	_ensure_state_store_ready()

func _subscribe_events() -> void:
	_event_unsubscribes.append(U_ECSEventBus.subscribe(EVENT_HEALTH_CHANGED, _on_health_changed))
	_event_unsubscribes.append(U_ECSEventBus.subscribe(EVENT_ENTITY_LANDED, _on_entity_landed))
	_event_unsubscribes.append(U_ECSEventBus.subscribe(EVENT_ENTITY_DEATH, _on_entity_death))

func process_tick(_delta: float) -> void:
	_ensure_state_store_ready()

func _on_health_changed(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var entity_id := StringName(payload.get("entity_id", ""))

	# Player-only gating
	if not _is_player_entity(entity_id):
		return

	var previous_health := float(payload.get("previous_health", 0.0))
	var new_health := float(payload.get("new_health", 0.0))
	var damage := maxf(previous_health - new_health, 0.0)

	if damage <= 0.0:
		return

	# Calculate trauma from damage (default: 0-100 damage → 0.3-0.6 trauma)
	var trauma := _calculate_damage_trauma(damage)

	# Publish VFX request
	var request := Evn_ScreenShakeRequest.new(entity_id, trauma, StringName("damage"))
	U_ECSEventBus.publish_typed(request)

func _on_entity_landed(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})

	# For landing events, entity is a Node reference
	var entity := payload.get("entity") as Node
	var entity_id := _get_entity_id_from_node(entity)

	# Player-only gating
	if not _is_player_entity(entity_id):
		return

	var vertical_velocity := float(payload.get("vertical_velocity", 0.0))
	var fall_speed := absf(vertical_velocity)

	# Calculate trauma from fall speed (default: threshold 15.0, speed 15-30 → 0.2-0.4 trauma)
	var trauma := _calculate_landing_trauma(fall_speed)

	if trauma <= 0.0:
		return

	# Publish VFX request
	var request := Evn_ScreenShakeRequest.new(entity_id, trauma, StringName("landing"))
	U_ECSEventBus.publish_typed(request)

func _on_entity_death(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var entity_id := StringName(payload.get("entity_id", ""))

	# Player-only gating
	if not _is_player_entity(entity_id):
		return

	# Fixed trauma for death (default: 0.5)
	var trauma := _get_death_trauma()

	# Publish VFX request
	var request := Evn_ScreenShakeRequest.new(entity_id, trauma, StringName("death"))
	U_ECSEventBus.publish_typed(request)

func _calculate_damage_trauma(damage: float) -> float:
	# If tuning resource is available, use it
	if tuning != null and tuning.has_method("calculate_damage_trauma"):
		return tuning.calculate_damage_trauma(damage)

	# Default fallback: 0-100 damage → 0.3-0.6 trauma
	var ratio := clampf(damage / 100.0, 0.0, 1.0)
	return lerpf(0.3, 0.6, ratio)

func _calculate_landing_trauma(fall_speed: float) -> float:
	# If tuning resource is available, use it
	if tuning != null and tuning.has_method("calculate_landing_trauma"):
		return tuning.calculate_landing_trauma(fall_speed)

	# Default fallback: threshold 15.0, speed 15-30 → 0.2-0.4 trauma
	if fall_speed < 15.0:
		return 0.0
	var ratio := clampf((fall_speed - 15.0) / 15.0, 0.0, 1.0)
	return lerpf(0.2, 0.4, ratio)

func _get_death_trauma() -> float:
	# If tuning resource is available, use it
	if tuning != null and tuning.has("death_trauma"):
		return float(tuning.get("death_trauma"))

	# Default fallback: 0.5
	return 0.5

func _is_player_entity(entity_id: StringName) -> bool:
	_ensure_state_store_ready()

	if _player_entity_id.is_empty():
		return false

	return entity_id == _player_entity_id

func _get_entity_id_from_node(entity: Node) -> StringName:
	if entity == null:
		return StringName("")

	# Try to get entity_id property if it exists
	if "entity_id" in entity:
		return StringName(entity.get("entity_id"))

	# Fallback to node name
	return StringName(entity.name)

func _ensure_state_store_ready() -> void:
	if _state_store != null and is_instance_valid(_state_store):
		_update_player_entity_id()
		return

	# Use injected store if available
	var store: I_StateStore = null
	if state_store != null:
		store = state_store
	else:
		store = U_StateUtils.try_get_store(self)

	if store == null:
		return

	_state_store = store
	_update_player_entity_id()

func _update_player_entity_id() -> void:
	if _state_store == null:
		return

	var state: Dictionary = _state_store.get_state()
	var gameplay_slice: Dictionary = state.get("gameplay", {})
	_player_entity_id = StringName(gameplay_slice.get("player_entity_id", "E_Player"))

func _exit_tree() -> void:
	for unsub in _event_unsubscribes:
		if unsub.is_valid():
			unsub.call()
	_event_unsubscribes.clear()
