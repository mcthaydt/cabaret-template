extends RefCounted
class_name U_StoreActionBinder

## Store Resolution and Action Signal Lifecycle Helper
##
## Manages the store discovery, signal connection, and disconnection pattern
## shared between M_ObjectivesManager and M_SceneDirectorManager. Eliminates
## ~65 lines of duplicated private methods by encapsulating the resolution logic
## and signal bookkeeping.
##
## Usage:
##   var _binder := U_StoreActionBinder.new()
##   # In _ready():   _binder.resolve(state_store, self, _on_action_dispatched)
##   # In _exit_tree(): _binder.disconnect_signal(_on_action_dispatched)
##   # Access store: _binder.store

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")

const STORE_SERVICE_NAME := StringName("state_store")

var store: I_StateStore = null
var _connected: bool = false


func resolve(exported_store: I_StateStore, owner_node: Node, callback: Callable) -> void:
	var resolved: I_StateStore = null
	if exported_store != null and is_instance_valid(exported_store):
		resolved = exported_store
	elif store != null and is_instance_valid(store):
		resolved = store
	else:
		resolved = U_STATE_UTILS.try_get_store(owner_node)
		if resolved == null:
			resolved = U_SERVICE_LOCATOR.try_get_service(STORE_SERVICE_NAME) as I_StateStore
	_set_store(resolved, callback)


func ensure_connection(callback: Callable) -> void:
	if store == null:
		return
	if not store.has_signal("action_dispatched"):
		return
	if store.action_dispatched.is_connected(callback):
		_connected = true
		return
	store.action_dispatched.connect(callback)
	_connected = true


func disconnect_signal(callback: Callable) -> void:
	if not _connected:
		return
	if store != null and store.has_signal("action_dispatched"):
		if store.action_dispatched.is_connected(callback):
			store.action_dispatched.disconnect(callback)
	_connected = false


func _set_store(next_store: I_StateStore, callback: Callable) -> void:
	if store != next_store:
		if store != null and store.has_signal("action_dispatched"):
			if store.action_dispatched.is_connected(callback):
				store.action_dispatched.disconnect(callback)
		_connected = false
		store = next_store
	ensure_connection(callback)
