@icon("res://assets/editor_icons/component.svg")
extends BaseECSComponent
class_name C_PlayerTagComponent

## C_PlayerTagComponent
##
## Lightweight tag component that marks an entity as a controllable player.
## Used by systems and triggers (e.g., C_SceneTriggerComponent) to identify
## the player entity via ECS rather than relying on scene groups.

const COMPONENT_TYPE := StringName("C_PlayerTagComponent")

func _init() -> void:
	component_type = COMPONENT_TYPE

