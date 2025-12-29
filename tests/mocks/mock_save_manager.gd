extends Node

## Mock Save Manager for autosave scheduler tests
## Tracks autosave requests without actually performing saves

const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")

const SLOT_AUTOSAVE := StringName("autosave")

var autosave_request_count: int = 0
var last_autosave_priority: int = 0
var _is_saving: bool = false
var _is_loading: bool = false
var _delayed_load_enabled: bool = false
var _delayed_load_duration: float = 0.0
var _slot_exists_map: Dictionary = {}  # StringName -> bool

func _init() -> void:
	name = "MockSaveManager"
	add_to_group("save_manager")

func _ready() -> void:
	# Register with ServiceLocator if available
	if has_node("/root/U_ServiceLocator"):
		var locator: Node = get_node("/root/U_ServiceLocator")
		if locator.has_method("register"):
			locator.register(StringName("save_manager"), self)

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
	_slot_exists_map.clear()

## Test helper to configure which slots exist
func set_slot_exists(slot_id: StringName, exists: bool) -> void:
	_slot_exists_map[slot_id] = exists

## Test helper to enable delayed load simulation
func set_delayed_load(enabled: bool, duration: float = 0.0) -> void:
	_delayed_load_enabled = enabled
	_delayed_load_duration = duration

## Mock implementation of get_all_slot_metadata
func get_all_slot_metadata() -> Array[Dictionary]:
	var metadata: Array[Dictionary] = []

	# Return mock metadata for autosave and 3 manual slots
	var autosave_exists: bool = _slot_exists_map.get(SLOT_AUTOSAVE, false)
	metadata.append({
		"slot_id": SLOT_AUTOSAVE,
		"exists": autosave_exists,
		"timestamp": "2025-12-27T10:00:00Z" if autosave_exists else "",
		"area_name": "Test Area" if autosave_exists else "",
		"playtime_seconds": 3600 if autosave_exists else 0
	})

	for i in range(1, 4):
		var slot_id: StringName = StringName("slot_0%d" % i)
		var slot_exists: bool = _slot_exists_map.get(slot_id, false)
		metadata.append({
			"slot_id": slot_id,
			"exists": slot_exists,
			"timestamp": "2025-12-27T10:00:00Z" if slot_exists else "",
			"area_name": "Test Area" if slot_exists else "",
			"playtime_seconds": 3600 if slot_exists else 0
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

	# Simulate immediate save completion
	await get_tree().process_frame
	_is_saving = false

	# Emit save_completed event
	U_ECSEventBus.publish(StringName("save_completed"), {
		"slot_id": slot_id
	})

	return OK

## Mock implementation of load_from_slot
func load_from_slot(slot_id: StringName) -> Error:
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
	return OK

## Mock implementation of slot_exists
func slot_exists(slot_id: StringName) -> bool:
	return _slot_exists_map.get(slot_id, false)
