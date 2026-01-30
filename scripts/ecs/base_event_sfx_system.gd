@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name BaseEventSFXSystem

## Base class for SFX systems that respond to ECS events.
##
## Provides common patterns for event-driven SFX systems:
## - Event subscription/unsubscription lifecycle
## - Request queue management
## - Payload extraction
## - Pause/transition blocking (Phase 6)
## - Shared helpers for throttling, pitch calculation, position extraction (Phase 6)
##
## Subclasses must implement:
## - get_event_name() -> StringName
## - create_request_from_payload(payload: Dictionary) -> Dictionary
## - _get_audio_stream() -> AudioStream (optional, returns null by default)

const EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_GAMEPLAY_SELECTORS := preload("res://scripts/state/selectors/u_gameplay_selectors.gd")
const U_SCENE_SELECTORS := preload("res://scripts/state/selectors/u_scene_selectors.gd")
const U_NAVIGATION_SELECTORS := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_SFX_SPAWNER := preload("res://scripts/managers/helpers/u_sfx_spawner.gd")

## Queue of SFX requests to be processed in process_tick().
var requests: Array = []

## Optional state store injection for pause/transition checking (Phase 6)
## Tests can inject mock store; production uses U_StateUtils.try_get_store()
@export var state_store: I_StateStore = null

var _unsubscribe_callable: Callable = Callable()

func _ready() -> void:
	super._ready()
	_subscribe()

func _exit_tree() -> void:
	_unsubscribe()
	requests.clear()

## Override in subclass to return the event name to subscribe to.
func get_event_name() -> StringName:
	push_error("BaseEventSFXSystem: get_event_name() not implemented")
	return StringName()

## Override in subclass to create a request dictionary from event payload.
func create_request_from_payload(_payload: Dictionary) -> Dictionary:
	push_error("BaseEventSFXSystem: create_request_from_payload() not implemented")
	return {}

func _subscribe() -> void:
	_unsubscribe()
	requests.clear()

	var event_name := get_event_name()
	if event_name == StringName():
		push_warning("BaseEventSFXSystem: get_event_name() returned empty StringName")
		return

	_unsubscribe_callable = EVENT_BUS.subscribe(event_name, _on_event)

func _unsubscribe() -> void:
	if _unsubscribe_callable != Callable() and _unsubscribe_callable.is_valid():
		_unsubscribe_callable.call()
	_unsubscribe_callable = Callable()

func _on_event(event_data: Dictionary) -> void:
	var payload := _extract_payload(event_data)
	var request := create_request_from_payload(payload)
	if request.is_empty():
		return
	requests.append(request.duplicate(true))

func _extract_payload(event_data: Dictionary) -> Dictionary:
	if event_data.has("payload") and event_data["payload"] is Dictionary:
		return event_data["payload"]
	return {}

## Phase 6: Shared helper methods for sound systems

## Override in subclass to return the audio stream from settings.
## Returns null by default.
func _get_audio_stream() -> AudioStream:
	return null

## Check if processing should be skipped (null/disabled settings, null stream).
## Clears requests if should skip.
func _should_skip_processing() -> bool:
	if not "settings" in self or self.get("settings") == null:
		requests.clear()
		return true

	var settings_dict: Variant = self.get("settings")
	if settings_dict is Dictionary:
		if not settings_dict.get("enabled", false):
			requests.clear()
			return true
	elif settings_dict is Resource:
		if "enabled" in settings_dict and not settings_dict.get("enabled"):
			requests.clear()
			return true

	var stream := _get_audio_stream()
	if stream == null:
		requests.clear()
		return true

	return false

## Check if audio is currently blocked (pause, transition, or not in gameplay).
## Returns false if no state store available (e.g., in tests).
func _is_audio_blocked() -> bool:
	var store: I_StateStore = state_store
	if store == null:
		store = U_STATE_UTILS.try_get_store(self)
	if store == null:
		return false

	var state: Dictionary = store.get_state()
	var gameplay_slice: Dictionary = state.get("gameplay", {})
	var scene_slice: Dictionary = state.get("scene", {})
	var navigation_slice: Dictionary = state.get("navigation", {})

	# Block if paused
	if U_GAMEPLAY_SELECTORS.get_is_paused(gameplay_slice):
		return true

	# Block if transitioning
	if U_SCENE_SELECTORS.is_transitioning(scene_slice):
		return true

	# Block if not in gameplay shell
	var current_shell: StringName = U_NAVIGATION_SELECTORS.get_shell(navigation_slice)
	if current_shell != StringName("gameplay"):
		return true

	return false

## Check if sound should be throttled based on min_interval.
## Uses _last_play_time field (must be defined in subclass).
func _is_throttled(min_interval: float, now: float) -> bool:
	if min_interval <= 0.0:
		return false

	if not "last_play_time" in self and not "_last_play_time" in self:
		return false

	var last_time: float = -INF
	if "_last_play_time" in self:
		last_time = self.get("_last_play_time")
	elif "last_play_time" in self:
		last_time = self.get("last_play_time")

	return now - last_time < min_interval

## Calculate randomized pitch with clamped variation (0.0-0.95).
func _calculate_pitch(pitch_variation: float) -> float:
	var clamped := clampf(pitch_variation, 0.0, 0.95)
	if clamped <= 0.0:
		return 1.0
	return randf_range(1.0 - clamped, 1.0 + clamped)

## Extract Vector3 position from request Dictionary.
## Returns Vector3.ZERO if missing or invalid type.
func _extract_position(request: Dictionary) -> Vector3:
	var position_variant: Variant = request.get("position", Vector3.ZERO)
	if position_variant is Vector3:
		return position_variant
	return Vector3.ZERO

## Spawn SFX using U_SFXSpawner with provided config.
func _spawn_sfx(config: Dictionary) -> void:
	U_SFX_SPAWNER.spawn_3d(config)
