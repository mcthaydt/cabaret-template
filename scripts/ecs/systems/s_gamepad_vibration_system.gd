@icon("res://resources/editor_icons/system.svg")
extends BaseECSSystem
class_name S_GamepadVibrationSystem

## Listens for gameplay events and dispatches gamepad vibration requests.
## Vibration intensity honors settings slice (enable flag + multiplier).

const GAMEPAD_TYPE := StringName("C_GamepadComponent")
const EVENT_ENTITY_LANDED := StringName("entity_landed")
const EVENT_ENTITY_DEATH := StringName("entity_death")
const EVENT_VIBRATION_REQUEST := StringName("gamepad_vibration_request")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const C_GamepadComponent := preload("res://scripts/ecs/components/c_gamepad_component.gd")

# Device type constants (match S_InputSystem.DeviceType)
const DEVICE_TYPE_KEYBOARD_MOUSE := 0
const DEVICE_TYPE_GAMEPAD := 1

var _state_store: M_StateStore = null
var _store_unsubscribe: Callable = Callable()
var _event_unsubscribes: Array[Callable] = []
var _gamepad_settings: Dictionary = {}
var _player_entity_id: String = "E_Player"
var _last_input_state: Dictionary = {}

func on_configured() -> void:
	_subscribe_events()
	_ensure_state_store_ready()

func _subscribe_events() -> void:
	_event_unsubscribes.append(U_ECSEventBus.subscribe(EVENT_ENTITY_LANDED, _on_entity_landed))
	# Priority 0 (default): Haptic feedback doesn't need high priority
	_event_unsubscribes.append(U_ECSEventBus.subscribe(EVENT_ENTITY_DEATH, _on_entity_death, 0))
	_event_unsubscribes.append(U_ECSEventBus.subscribe(EVENT_VIBRATION_REQUEST, _on_vibration_request))

func process_tick(_delta: float) -> void:
	# No-op; system reacts to events/state changes.
	pass

func _on_entity_landed(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var entity := payload.get("entity") as Node
	var entity_id := _get_entity_id_from_node(entity)
	if entity_id.is_empty() or not _is_player_entity(entity_id):
		return
	_trigger_vibration(0.2, 0.1, 0.1)

func _on_entity_death(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var entity_id := String(payload.get("entity_id", ""))
	if _is_player_entity(entity_id):
		_trigger_death_vibration()

func _on_vibration_request(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var weak := float(payload.get("weak", payload.get("weak_magnitude", 0.0)))
	var strong := float(payload.get("strong", payload.get("strong_magnitude", 0.0)))
	var duration := float(payload.get("duration", 0.0))
	_trigger_vibration(weak, strong, duration)

func _trigger_damage_vibration(_amount: float) -> void:
	_trigger_vibration(0.5, 0.3, 0.2)

func _trigger_death_vibration() -> void:
	_trigger_vibration(0.8, 0.6, 0.4)

func _trigger_vibration(weak: float, strong: float, duration: float) -> void:
	_ensure_state_store_ready()
	if not _gamepad_settings.get("vibration_enabled", true):
		return

	# Only vibrate if active device is a gamepad
	var active_device_type := int(_last_input_state.get("active_device", DEVICE_TYPE_KEYBOARD_MOUSE))
	if active_device_type != DEVICE_TYPE_GAMEPAD:
		return

	var device_id := _get_active_gamepad_id()
	if device_id < 0:
		return
	var intensity := clampf(float(_gamepad_settings.get("vibration_intensity", 1.0)), 0.0, 1.0)
	var adjusted_weak := clampf(abs(weak) * intensity, 0.0, 1.0)
	var adjusted_strong := clampf(abs(strong) * intensity, 0.0, 1.0)
	var duration_sec: float = max(duration, 0.0)
	var components := get_components(GAMEPAD_TYPE)
	for entry in components:
		var comp := entry as C_GamepadComponent
		if comp == null:
			continue
		if comp.device_id == device_id:
			comp.apply_rumble(adjusted_weak, adjusted_strong, duration_sec)
			return
	Input.start_joy_vibration(device_id, adjusted_weak, adjusted_strong, duration_sec)

func _ensure_state_store_ready() -> void:
	if _state_store != null and is_instance_valid(_state_store):
		return

	_teardown_store_subscription()

	var store := U_StateUtils.get_store(self)
	if store == null:
		return

	_state_store = store
	_store_unsubscribe = store.subscribe(_on_state_store_changed)
	_apply_settings_from_state(store.get_state())

func _get_state_store() -> M_StateStore:
	if _state_store != null and is_instance_valid(_state_store):
		return _state_store
	_teardown_store_subscription()
	return null

func _on_state_store_changed(action: Dictionary, state: Dictionary) -> void:
	if action != null:
		var action_type: StringName = action.get("type", StringName())
		if action_type == U_GameplayActions.ACTION_TAKE_DAMAGE:
			var payload: Dictionary = action.get("payload", {})
			var entity_id := String(payload.get("entity_id", ""))
			if _is_player_entity(entity_id):
				_trigger_damage_vibration(float(payload.get("amount", 0.0)))
	_apply_settings_from_state(state)

func _apply_settings_from_state(state: Dictionary) -> void:
	if state == null:
		return
	var settings := U_InputSelectors.get_gamepad_settings(state)
	_gamepad_settings = settings.duplicate(true)
	var gameplay: Variant = state.get("gameplay", {})
	if gameplay is Dictionary:
		var gameplay_dict := gameplay as Dictionary
		_player_entity_id = String(gameplay_dict.get("player_entity_id", _player_entity_id))
		if gameplay_dict.has("input") and gameplay_dict["input"] is Dictionary:
			_last_input_state = (gameplay_dict["input"] as Dictionary).duplicate(true)

func _teardown_store_subscription() -> void:
	if _store_unsubscribe != Callable() and _store_unsubscribe.is_valid():
		_store_unsubscribe.call()
	_store_unsubscribe = Callable()
	_state_store = null

func _exit_tree() -> void:
	_teardown_store_subscription()
	for unsubscribe in _event_unsubscribes:
		if unsubscribe != null and unsubscribe is Callable and (unsubscribe as Callable).is_valid():
			(unsubscribe as Callable).call()
	_event_unsubscribes.clear()

func _get_active_gamepad_id() -> int:
	if _last_input_state.is_empty():
		return _get_component_device_id()
	var connected := bool(_last_input_state.get("gamepad_connected", false))
	if not connected:
		return _get_component_device_id()
	return int(_last_input_state.get("gamepad_device_id", -1))

func _get_component_device_id() -> int:
	var components := get_components(GAMEPAD_TYPE)
	for entry in components:
		var comp := entry as C_GamepadComponent
		if comp == null:
			continue
		if comp.device_id >= 0:
			return comp.device_id
	return -1

func _is_player_entity(entity_id: String) -> bool:
	if entity_id.is_empty():
		return false
	var normalized := entity_id.to_lower()
	var expected := String(_player_entity_id).to_lower()
	if normalized == expected:
		return true
	return normalized.contains("player")

func _get_entity_id_from_node(entity: Node) -> String:
	if entity == null:
		return ""
	if entity.has_meta("entity_id"):
		var meta_value: Variant = entity.get_meta("entity_id")
		return String(meta_value)
	return String(entity.name)
