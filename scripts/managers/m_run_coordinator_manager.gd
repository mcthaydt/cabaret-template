@icon("res://assets/editor_icons/icn_manager.svg")
extends I_RunCoordinator
class_name M_RunCoordinatorManager

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")
const U_RUN_ACTIONS := preload("res://scripts/state/actions/u_run_actions.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_INTERACT_BLOCKER := preload("res://scripts/utils/u_interact_blocker.gd")

const OBJECTIVES_SERVICE_NAME := StringName("objectives_manager")

@export var state_store: I_StateStore = null
@export var game_config: RS_GameConfig = null

var _store: I_StateStore = null
var _store_action_connected: bool = false
var _is_reset_in_flight: bool = false

func _ready() -> void:
	if game_config == null:
		game_config = RS_GameConfig.new()
	_resolve_state_store()
	_ensure_store_action_signal_connection()
	call_deferred("_validate_game_config_references")

func _physics_process(_delta: float) -> void:
	# Keep retrying in case store registration is late.
	if _store == null:
		_resolve_state_store()

func _exit_tree() -> void:
	_disconnect_store_action_signal()

func _resolve_state_store() -> void:
	var resolved_store: I_StateStore = U_DependencyResolution.resolve_state_store(_store, state_store, self) as I_StateStore
	_set_store_reference(resolved_store)

func _set_store_reference(next_store: I_StateStore) -> void:
	if _store != next_store:
		if _store != null and _store.has_signal("action_dispatched"):
			if _store.action_dispatched.is_connected(_on_action_dispatched):
				_store.action_dispatched.disconnect(_on_action_dispatched)
		_store_action_connected = false
		_store = next_store

	_ensure_store_action_signal_connection()

func _ensure_store_action_signal_connection() -> void:
	if _store == null:
		return
	if not _store.has_signal("action_dispatched"):
		return
	if _store.action_dispatched.is_connected(_on_action_dispatched):
		_store_action_connected = true
		return

	_store.action_dispatched.connect(_on_action_dispatched)
	_store_action_connected = true

func _disconnect_store_action_signal() -> void:
	if not _store_action_connected:
		return
	if _store != null and _store.has_signal("action_dispatched"):
		if _store.action_dispatched.is_connected(_on_action_dispatched):
			_store.action_dispatched.disconnect(_on_action_dispatched)
	_store_action_connected = false

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: StringName = _to_string_name(action.get("type", StringName("")))
	if action_type != U_RUN_ACTIONS.ACTION_RESET_RUN:
		return
	if _is_reset_in_flight:
		return

	_is_reset_in_flight = true
	var next_route: StringName = _resolve_next_route(action)
	_execute_reset_run(next_route)
	call_deferred("_complete_reset_request")

func _complete_reset_request() -> void:
	_is_reset_in_flight = false

func _execute_reset_run(next_route: StringName) -> void:
	_resolve_state_store()
	if _store == null:
		_warn("No state store available for run/reset.")
		return

	_store.dispatch(U_GAMEPLAY_ACTIONS.reset_progress())
	U_INTERACT_BLOCKER.force_unblock()

	var objectives_manager: I_ObjectivesManager = U_SERVICE_LOCATOR.try_get_service(OBJECTIVES_SERVICE_NAME) as I_ObjectivesManager
	if objectives_manager != null and is_instance_valid(objectives_manager):
		objectives_manager.reset_for_new_run(game_config.default_objective_set_id)
	else:
		_warn("objectives_manager not available during run/reset.")

	var retry_scene_id: StringName = _resolve_retry_scene_id(next_route)
	_store.dispatch(U_NAVIGATION_ACTIONS.retry(retry_scene_id))

func _resolve_next_route(action: Dictionary) -> StringName:
	var payload_variant: Variant = action.get("payload", {})
	if payload_variant is Dictionary:
		var payload: Dictionary = payload_variant as Dictionary
		var next_route: StringName = _to_string_name(payload.get("next_route", game_config.route_retry))
		if next_route != StringName(""):
			return next_route
	return game_config.route_retry

func _resolve_retry_scene_id(next_route: StringName) -> StringName:
	if next_route == game_config.route_retry:
		return game_config.retry_scene_id
	_warn("Unknown run/reset next_route '%s'; defaulting to retry scene '%s'." % [
		String(next_route),
		String(game_config.retry_scene_id),
	])
	return game_config.retry_scene_id

static func _to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName("")

func is_reset_in_flight() -> bool:
	return _is_reset_in_flight

func _validate_game_config_references() -> void:
	var retry_scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(game_config.retry_scene_id)
	if retry_scene_data.is_empty():
		push_error("M_RunCoordinatorManager: game_config.retry_scene_id '%s' not found in U_SceneRegistry. Resource: %s" % [String(game_config.retry_scene_id), game_config.resource_path])

	var objectives_manager: I_ObjectivesManager = U_SERVICE_LOCATOR.try_get_service(OBJECTIVES_SERVICE_NAME) as I_ObjectivesManager
	if objectives_manager != null and is_instance_valid(objectives_manager):
		if not objectives_manager.has_objective_set(game_config.default_objective_set_id):
			push_error("M_RunCoordinatorManager: game_config.default_objective_set_id '%s' not found in objectives registry. Resource: %s" % [String(game_config.default_objective_set_id), game_config.resource_path])

func _warn(message: String) -> void:
	push_warning("M_RunCoordinatorManager: %s" % message)
