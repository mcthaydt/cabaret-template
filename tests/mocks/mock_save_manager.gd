extends "res://scripts/interfaces/i_save_manager.gd"
class_name MockSaveManager

## Mock Save Manager for autosave scheduler tests
## Tracks autosave requests without actually performing saves

const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

const SLOT_AUTOSAVE := StringName("autosave")

var autosave_request_count: int = 0
var last_autosave_priority: int = 0
var _is_saving: bool = false
var _is_loading: bool = false
var _delayed_load_enabled: bool = false
var _delayed_load_duration: float = 0.0
var _next_save_result: Error = OK
var _next_load_result: Error = OK
var _next_delete_result: Error = OK
var _has_any_saves: bool = false
var _most_recent_save_slot: StringName = StringName("")

func _init() -> void:
	name = "MockSaveManager"

func _ready() -> void:
	var existing := U_ServiceLocator.try_get_service(StringName("save_manager"))
	if existing == null:
		U_ServiceLocator.register(StringName("save_manager"), self)

func request_autosave(priority: int = 0) -> void:
	autosave_request_count += 1
	last_autosave_priority = priority

func is_locked() -> bool:
	return _is_saving or _is_loading

func set_locked(locked: bool) -> void:
	_is_saving = locked
	_is_loading = locked

func reset() -> void:
	autosave_request_count = 0
	last_autosave_priority = 0
	_is_saving = false
	_is_loading = false
	_delayed_load_enabled = false
	_delayed_load_duration = 0.0
	_next_save_result = OK
	_next_load_result = OK
	_next_delete_result = OK
	_has_any_saves = false
	_most_recent_save_slot = StringName("")

func set_next_save_result(result: Error) -> void:
	_next_save_result = result

func set_next_load_result(result: Error) -> void:
	_next_load_result = result

func set_next_delete_result(result: Error) -> void:
	_next_delete_result = result

func set_has_any_saves(has_saves: bool) -> void:
	_has_any_saves = has_saves
	if _has_any_saves and _most_recent_save_slot == StringName(""):
		_most_recent_save_slot = StringName("slot_01")

func set_most_recent_save_slot(slot_id: StringName) -> void:
	_most_recent_save_slot = slot_id

func has_any_saves() -> bool:
	return _has_any_saves

func get_most_recent_save_slot() -> StringName:
	if not _has_any_saves:
		return StringName("")
	return _most_recent_save_slot

## Test helper to enable delayed load simulation
func set_delayed_load(enabled: bool, duration: float = 0.0) -> void:
	_delayed_load_enabled = enabled
	_delayed_load_duration = duration

## Mock implementation of get_all_slot_metadata
func get_all_slot_metadata() -> Array[Dictionary]:
	var metadata: Array[Dictionary] = []

	# Return mock metadata for autosave and 3 manual slots
	metadata.append({
		"slot_id": SLOT_AUTOSAVE,
		"exists": false,
		"timestamp": "",
		"area_name": "",
		"playtime_seconds": 0
	})

	for i in range(1, 4):
		metadata.append({
			"slot_id": StringName("slot_0%d" % i),
			"exists": false,
			"timestamp": "",
			"area_name": "",
			"playtime_seconds": 0
		})

	return metadata

## Mock implementation of save_to_slot
func save_to_slot(slot_id: StringName) -> Error:
	_is_saving = true

	# Emit save_started event
	U_ECSEventBus.publish(StringName("save_started"), {
		"slot_id": slot_id,
		"is_autosave": (slot_id == SLOT_AUTOSAVE)
	})

	var result: Error = _next_save_result
	_next_save_result = OK
	_is_saving = false

	# Emit save_completed event
	if result == OK:
		U_ECSEventBus.publish(StringName("save_completed"), {
			"slot_id": slot_id
		})
	else:
		U_ECSEventBus.publish(StringName("save_failed"), {
			"slot_id": slot_id,
			"error_code": result
		})

	return result

## Mock implementation of load_from_slot
func load_from_slot(slot_id: StringName) -> Error:
	var result: Error = _next_load_result
	_next_load_result = OK

	if result != OK:
		U_ECSEventBus.publish(StringName("load_failed"), {
			"slot_id": slot_id,
			"error_code": result
		})
		return result

	_is_loading = true

	# Emit load_started event immediately
	U_ECSEventBus.publish(StringName("load_started"), {
		"slot_id": slot_id
	})

	# Schedule load completion for later (simulates async load)
	if _delayed_load_enabled and _delayed_load_duration > 0.0:
		get_tree().create_timer(_delayed_load_duration).timeout.connect(_complete_load.bind(slot_id))
	else:
		# Complete immediately on next frame
		call_deferred("_complete_load", slot_id)

	return OK

func _complete_load(slot_id: StringName) -> void:
	_is_loading = false

	# Emit load_completed event
	U_ECSEventBus.publish(StringName("load_completed"), {
		"slot_id": slot_id
	})

## Mock implementation of delete_slot
func delete_slot(slot_id: StringName) -> Error:
	if slot_id == SLOT_AUTOSAVE:
		return ERR_UNAUTHORIZED
	var result: Error = _next_delete_result
	_next_delete_result = OK
	return result

## Mock implementation of slot_exists
func slot_exists(slot_id: StringName) -> bool:
	return false  # All slots empty by default in mock
