@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_GameConfig

## Game-specific configuration for run coordinator and objectives manager.
##
## Wire a cfg_game_config.tres instance on M_RunCoordinatorManager and
## M_ObjectivesManager in root.tscn to configure template-specific IDs
## without touching manager code.

## Scene to load when retrying (navigating back to start of run).
@export var retry_scene_id: StringName = StringName("alleyway")

## Route action name dispatched with run/reset to trigger a retry.
@export var route_retry: StringName = StringName("retry_alleyway")

## Objective set ID loaded at the start of a new run.
@export var default_objective_set_id: StringName = StringName("default_progression")

## Area ID that must be in completed_areas before GAME_COMPLETE victory can fire.
@export var required_final_area: String = "bar"
