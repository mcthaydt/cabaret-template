@icon("res://resources/editor_icons/resource.svg")
extends Resource
class_name RS_StateStoreSettings

## Configuration settings for M_StateStore
##
## Controls history size, performance features, persistence, and debug options.

@export_group("History")
@export var max_history_size: int = 1000
@export var enable_history: bool = true

@export_group("Performance")
@export var enable_signal_batching: bool = true

@export_group("Persistence")
@export var enable_persistence: bool = true
@export var auto_save_interval: float = 60.0
@export var save_path_override: String = ""

@export_group("Debug")
@export var enable_debug_overlay: bool = OS.is_debug_build()
@export var enable_debug_logging: bool = OS.is_debug_build()

## Convert settings to dictionary for serialization
func to_dictionary() -> Dictionary:
	return {
		"max_history_size": max_history_size,
		"enable_history": enable_history,
		"enable_signal_batching": enable_signal_batching,
		"enable_persistence": enable_persistence,
		"auto_save_interval": auto_save_interval,
		"save_path_override": save_path_override,
		"enable_debug_overlay": enable_debug_overlay,
		"enable_debug_logging": enable_debug_logging,
	}
