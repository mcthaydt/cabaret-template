@icon("res://assets/editor_icons/resource.svg")
extends Resource
class_name RS_StateSliceConfig

## Configuration for a state slice
##
## Defines metadata for each slice including its reducer, dependencies,
## and which fields should be excluded from persistence (transient).

@export var slice_name: StringName = StringName()
@export var dependencies: Array[StringName] = []
@export var is_transient: bool = false

## Fields marked transient will not be saved to disk.
##
## Use for cache, temporary UI state, derived values, or any data that
## should not persist across save/load cycles.
##
## Example: ["cached_calculations", "ui_scroll_position", "temp_filter"]
@export var transient_fields: Array[StringName] = []

## Entire slice transient flag (skips persistence and StateHandoff)
var reducer: Callable = Callable()
var initial_state: Dictionary = {}

func _init(p_slice_name: StringName = StringName()) -> void:
	slice_name = p_slice_name
