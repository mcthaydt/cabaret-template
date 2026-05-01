@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_GameConfig

## Game-specific configuration for run coordinator and objectives manager.
##
## Wire a cfg_game_config.tres instance on M_RunCoordinatorManager and
## M_ObjectivesManager in root.tscn to configure template-specific IDs
## without touching manager code.
##
## Schema validation (F15): required fields must be non-empty. Setting any
## required field to empty pushes an error with resource_path for designer traceability.

## Scene to load for a new run from the main menu and boot-time preloading.
var _default_gameplay_scene_id: StringName = StringName("demo_room")

@export var default_gameplay_scene_id: StringName = StringName("demo_room"):
	get:
		return _default_gameplay_scene_id
	set(value):
		_default_gameplay_scene_id = value
		if value == StringName(""):
			push_error("RS_GameConfig: default_gameplay_scene_id must not be empty. Resource: %s" % resource_path)

## Scene to load when retrying. Empty means use default_gameplay_scene_id.
var _retry_scene_id: StringName = StringName("demo_room")

@export var retry_scene_id: StringName = StringName("demo_room"):
	get:
		return _retry_scene_id
	set(value):
		_retry_scene_id = value

## Route action name dispatched with run/reset to trigger a retry.
var _route_retry: StringName = StringName("retry")

@export var route_retry: StringName = StringName("retry"):
	get:
		return _route_retry
	set(value):
		_route_retry = value
		if value == StringName(""):
			push_error("RS_GameConfig: route_retry must not be empty. Resource: %s" % resource_path)

## Objective set ID loaded at the start of a new run.
var _default_objective_set_id: StringName = StringName("default_progression")

@export var default_objective_set_id: StringName = StringName("default_progression"):
	get:
		return _default_objective_set_id
	set(value):
		_default_objective_set_id = value
		if value == StringName(""):
			push_error("RS_GameConfig: default_objective_set_id must not be empty. Resource: %s" % resource_path)

## Area ID that must be in completed_areas before GAME_COMPLETE victory can fire.
var _required_final_area: String = "demo_room"

@export var required_final_area: String = "demo_room":
	get:
		return _required_final_area
	set(value):
		_required_final_area = value
		if value == "":
			push_error("RS_GameConfig: required_final_area must not be empty. Resource: %s" % resource_path)

func get_default_gameplay_scene_id() -> StringName:
	return default_gameplay_scene_id

func get_retry_scene_id() -> StringName:
	if retry_scene_id == StringName(""):
		return get_default_gameplay_scene_id()
	return retry_scene_id
