@icon("res://resources/editor_icons/manager.svg")
extends Node
class_name M_SaveManager

## Save Manager - Coordinates save/load timing, slot management, and disk IO
##
## Responsibilities:
## - Manage save slots (autosave + 3 manual slots)
## - Coordinate save/load operations with atomic writes
## - Handle migrations and versioning
## - Emit save/load events for UI integration
## - Block autosaves during critical operations (death, loading)
##
## Discovery: Add to "save_manager" group, discoverable via ServiceLocator
##
## Dependencies:
## - M_StateStore: State access and dispatch
## - M_SceneManager: Scene transitions during load

const I_STATE_STORE := preload("res://scripts/interfaces/i_state_store.gd")

## Internal references
var _state_store: I_StateStore = null
var _scene_manager: Node = null  # M_SceneManager

## Lock flags to prevent concurrent operations
var _is_saving: bool = false
var _is_loading: bool = false

func _ready() -> void:
	# Add to save_manager group for discovery
	add_to_group("save_manager")

	# Register with ServiceLocator
	U_ServiceLocator.register(StringName("save_manager"), self)

	# Wait for ServiceLocator to initialize other services
	await get_tree().process_frame

	# Discover dependencies via ServiceLocator
	_state_store = U_ServiceLocator.get_service(StringName("state_store")) as I_StateStore
	if not _state_store:
		push_error("M_SaveManager: No M_StateStore registered with ServiceLocator")
		return

	_scene_manager = U_ServiceLocator.try_get_service(StringName("scene_manager"))
	if not _scene_manager:
		push_warning("M_SaveManager: No M_SceneManager registered with ServiceLocator")

## Get state store reference (for testing)
func _get_state_store() -> I_StateStore:
	return _state_store

## Get scene manager reference (for testing)
func _get_scene_manager() -> Node:
	return _scene_manager

## Check if save operation is locked (for testing)
func _is_saving_locked() -> bool:
	return _is_saving

## Check if load operation is locked (for testing)
func _is_loading_locked() -> bool:
	return _is_loading
