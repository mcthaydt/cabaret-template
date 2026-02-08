@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_SceneTriggerSystem

## Scene Trigger System
##
## ECS system for handling scene trigger components (door triggers, area transitions).
## Processes INTERACT mode triggers - checking for interact input when player is in trigger zone.
## AUTO mode triggers are handled directly by C_SceneTriggerComponent collision callbacks.

const COMPONENT_TYPE := StringName("C_SceneTriggerComponent")
const SYSTEM_TYPE := StringName("S_SceneTriggerSystem")

## Interact action (default: "ui_accept" or "E" key)
@export var interact_action: StringName = StringName("interact")

var _actions_validated: bool = false
var _actions_valid: bool = true

func _validate_interact_action() -> void:
	if _actions_validated:
		return
	_actions_validated = true

	_actions_valid = U_InputMapBootstrapper.validate_required_actions([interact_action])
	if _actions_valid:
		return

	push_error("S_SceneTriggerSystem: Missing required InputMap action '%s' (fix project.godot / boot init; INTERACT triggers will not fire)" % [interact_action])

func process_tick(_delta: float) -> void:
	if _manager == null:
		return
	
	_validate_interact_action()
	if not _actions_valid:
		return

	# Get all scene trigger components
	var triggers: Array = _manager.get_components(COMPONENT_TYPE)
	if triggers.is_empty():
		return

	# Check if interact key was just pressed
	var interact_just_pressed: bool = Input.is_action_just_pressed(interact_action)

	# Process INTERACT mode triggers
	for trigger in triggers:
		if trigger is C_SceneTriggerComponent:
			# Only handle INTERACT mode (AUTO mode handled by component's collision callbacks)
			if trigger.trigger_mode == C_SceneTriggerComponent.TriggerMode.INTERACT:
				# Check if player is in zone and interact key pressed
				if interact_just_pressed and trigger.is_player_in_zone():
					trigger.trigger_interact()
