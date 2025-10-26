extends Resource
class_name StateSliceConfig

## Configuration for a state slice
##
## Defines metadata for each slice including its reducer, dependencies,
## and which fields should be excluded from persistence (transient).

@export var slice_name: StringName = StringName()
@export var dependencies: Array[StringName] = []
@export var transient_fields: Array[StringName] = []

var reducer: Callable = Callable()
var initial_state: Dictionary = {}

func _init(p_slice_name: StringName = StringName()) -> void:
	slice_name = p_slice_name
