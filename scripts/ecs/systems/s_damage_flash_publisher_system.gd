@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_DamageFlashPublisherSystem

## Translates raw gameplay events into VFX damage flash requests.
## Performs player-only gating at the publisher level.
##
## Subscribes to: health_changed, entity_death
## Publishes: damage_flash_request

const EVENT_HEALTH_CHANGED := StringName("health_changed")
const EVENT_ENTITY_DEATH := StringName("entity_death")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const Evn_DamageFlashRequest := preload("res://scripts/ecs/events/evn_damage_flash_request.gd")

## Injected state store (for testing)
@export var state_store: I_StateStore = null

var _state_store: I_StateStore = null
var _event_unsubscribes: Array[Callable] = []
var _player_entity_id: StringName = StringName("")

func on_configured() -> void:
	_subscribe_events()
	_ensure_state_store_ready()

func _subscribe_events() -> void:
	_event_unsubscribes.append(U_ECSEventBus.subscribe(EVENT_HEALTH_CHANGED, _on_health_changed))
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

	# Scale intensity with damage (0-100 damage → 0.3-1.0 intensity)
	var intensity := clampf(lerpf(0.3, 1.0, damage / 100.0), 0.3, 1.0)

	# Publish VFX request
	var request := Evn_DamageFlashRequest.new(entity_id, intensity, StringName("damage"))
	U_ECSEventBus.publish_typed(request)

func _on_entity_death(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var entity_id := StringName(payload.get("entity_id", ""))

	# Player-only gating
	if not _is_player_entity(entity_id):
		return

	# Full intensity for death
	var intensity := 1.0

	# Publish VFX request
	var request := Evn_DamageFlashRequest.new(entity_id, intensity, StringName("death"))
	U_ECSEventBus.publish_typed(request)

func _is_player_entity(entity_id: StringName) -> bool:
	_ensure_state_store_ready()

	if _player_entity_id.is_empty():
		return false

	return entity_id == _player_entity_id

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
