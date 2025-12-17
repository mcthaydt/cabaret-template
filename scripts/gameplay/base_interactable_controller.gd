extends "res://scripts/gameplay/base_volume_controller.gd"
class_name BaseInteractableController

# U_ECS_UTILS inherited from BaseECSEntity (via base_volume_controller.gd)
const STATE_STORE_GROUP := StringName("state_store")
const SCENE_MANAGER_GROUP := StringName("scene_manager")
const PLAYER_TAG_COMPONENT := StringName("C_PlayerTagComponent")

signal player_entered(player: Node3D)
signal player_exited(player: Node3D)
signal activated(player: Node3D)

@export var cooldown_duration: float = 0.5

var _tracked_players: Dictionary = {}
var _cooldown_remaining: float = 0.0
var _is_locked: bool = false
var _cached_manager: M_ECSManager
var _cached_store: M_StateStore
var _arming_frames_remaining: int = 0
var _is_armed: bool = false
var _area_enter_callable: Callable = Callable()
var _area_exit_callable: Callable = Callable()
func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(true)
	trigger_area_ready.connect(_on_trigger_area_ready)
	var existing_area := get_trigger_area()
	if existing_area != null:
		_on_trigger_area_ready(existing_area)

func _exit_tree() -> void:
	_disconnect_trigger_area_signals(get_trigger_area())
	_clear_tracked_players(false)
	_cached_manager = null
	_cached_store = null
	_area_enter_callable = Callable()
	_area_exit_callable = Callable()
	super._exit_tree()

func _physics_process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = max(0.0, _cooldown_remaining - delta)

	if _arming_frames_remaining > 0:
		_arming_frames_remaining -= 1
		if _arming_frames_remaining <= 0:
			_arm_trigger()
	var settings := _get_settings()
	if not settings.ignore_initial_overlap and is_enabled() and _tracked_players.is_empty():
		_register_existing_overlaps()

func is_player_in_zone() -> bool:
	return not _tracked_players.is_empty()

func get_players() -> Array:
	return _tracked_players.values().duplicate(true)

func get_primary_player() -> Node3D:
	for player in _tracked_players.values():
		return player
	return null

func is_locked() -> bool:
	return _is_locked

func lock() -> void:
	_is_locked = true

func unlock() -> void:
	_is_locked = false

func force_cooldown_reset() -> void:
	_cooldown_remaining = 0.0

func can_activate() -> bool:
	if _is_locked:
		return false
	if not _is_armed:
		return false
	if not is_enabled():
		return false
	if _tracked_players.is_empty():
		return false
	if _is_transition_blocked():
		return false
	return _cooldown_remaining <= 0.0

func activate(player: Node3D) -> bool:
	if not can_activate():
		return false

	_cooldown_remaining = max(0.0, cooldown_duration)
	activated.emit(player)
	_on_activated(player)
	return true

func _on_trigger_area_ready(area: Area3D) -> void:
	if not is_instance_valid(area):
		return
	_disconnect_trigger_area_signals(area)
	_area_enter_callable = Callable(self, "_on_trigger_area_body_entered")
	_area_exit_callable = Callable(self, "_on_trigger_area_body_exited")
	if not area.body_entered.is_connected(_area_enter_callable):
		area.body_entered.connect(_area_enter_callable)
	if not area.body_exited.is_connected(_area_exit_callable):
		area.body_exited.connect(_area_exit_callable)
	_schedule_arming()

func _schedule_arming() -> void:
	_is_armed = false
	var settings := _get_settings()
	_arming_frames_remaining = max(0, settings.arm_delay_physics_frames)
	if _arming_frames_remaining == 0:
		_arm_trigger()

func _arm_trigger() -> void:
	_is_armed = true
	_arming_frames_remaining = 0
	var settings := _get_settings()
	if settings.ignore_initial_overlap:
		return
	_register_existing_overlaps()

func _register_existing_overlaps() -> void:
	var area := get_trigger_area()
	if area == null:
		return
	if not area.monitoring:
		area.monitoring = true
		area.monitorable = true
	var overlaps := area.get_overlapping_bodies()
	for body in overlaps:
		if body is Node3D:
			_handle_body_entered(body)

func _on_trigger_area_body_entered(body: Node) -> void:
	if not (body is Node3D):
		return
	_handle_body_entered(body as Node3D)

func _on_trigger_area_body_exited(body: Node) -> void:
	if not (body is Node3D):
		return
	_handle_body_exited(body as Node3D)

func _handle_body_entered(body: Node3D) -> void:
	var entity := _resolve_player_entity(body)
	if entity == null:
		return
	if _tracked_players.has(body):
		return
	_tracked_players[body] = entity
	player_entered.emit(entity)
	_on_player_entered(entity)

func _handle_body_exited(body: Node3D) -> void:
	if not _tracked_players.has(body):
		return
	var entity := _tracked_players.get(body) as Node3D
	_tracked_players.erase(body)
	if entity != null:
		player_exited.emit(entity)
		_on_player_exited(entity)

func _resolve_player_entity(body: Node3D) -> Node3D:
	if body == null:
		return null
	var entity := U_ECS_UTILS.find_entity_root(body)
	if entity == null:
		return null
	var manager := _get_manager()
	if manager == null:
		return null
	var components := manager.get_components_for_entity(entity)
	if not components.has(PLAYER_TAG_COMPONENT):
		return null
	if components.get(PLAYER_TAG_COMPONENT) == null:
		return null
	return entity

func _clear_tracked_players(emit_signals: bool) -> void:
	if _tracked_players.is_empty():
		return
	var exiting_players := _tracked_players.values()
	_tracked_players.clear()
	if not emit_signals:
		return
	for player in exiting_players:
		if player is Node3D:
			player_exited.emit(player as Node3D)
			_on_player_exited(player as Node3D)

func _get_manager() -> M_ECSManager:
	if _cached_manager != null and is_instance_valid(_cached_manager):
		return _cached_manager
	_cached_manager = U_ECS_UTILS.get_manager(self) as M_ECSManager
	return _cached_manager

func _get_store() -> M_StateStore:
	if _cached_store != null and is_instance_valid(_cached_store):
		return _cached_store
	var tree := get_tree()
	if tree == null:
		return null
	var stores := tree.get_nodes_in_group(STATE_STORE_GROUP)
	if stores.is_empty():
		return null
	_cached_store = stores[0] as M_StateStore
	return _cached_store

func _is_transition_blocked() -> bool:
	var store := _get_store()
	if store != null:
		var scene_slice: Dictionary = store.get_slice(StringName("scene"))
		if scene_slice.get("is_transitioning", false):
			return true
		# Block interactions while any UI overlay is active (paused/menus)
		var stack: Array = scene_slice.get("scene_stack", [])
		if stack.size() > 0:
			return true
	# Check if scene manager is transitioning via ServiceLocator (Phase 10B-7: T141c)
	# Use try_get_service to avoid errors in test environments
	var manager := U_ServiceLocator.try_get_service(SCENE_MANAGER_GROUP)
	if manager != null and manager.has_method("is_transitioning") and manager.is_transitioning():
		return true
	return false

func _disconnect_trigger_area_signals(area: Area3D) -> void:
	if area == null or not is_instance_valid(area):
		return
	if _area_enter_callable != Callable() and area.body_entered.is_connected(_area_enter_callable):
		area.body_entered.disconnect(_area_enter_callable)
	if _area_exit_callable != Callable() and area.body_exited.is_connected(_area_exit_callable):
		area.body_exited.disconnect(_area_exit_callable)

func _on_enabled_state_changed(enabled: bool) -> void:
	super._on_enabled_state_changed(enabled)
	if not enabled:
		_is_armed = false
		_arming_frames_remaining = max(0, _get_settings().arm_delay_physics_frames)
		_clear_tracked_players(true)
	else:
		_schedule_arming()

func _on_player_entered(_player: Node3D) -> void:
	# Hook for subclasses.
	pass

func _on_player_exited(_player: Node3D) -> void:
	# Hook for subclasses.
	pass

func _on_activated(_player: Node3D) -> void:
	# Hook for subclasses.
	pass
