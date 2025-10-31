@icon("res://resources/editor_icons/system.svg")
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

var _actions_initialized: bool = false

func _ready() -> void:
	super._ready()
	_ensure_interact_action()

func _ensure_interact_action() -> void:
	if _actions_initialized:
		return

	# Ensure interact action exists in InputMap
	if not InputMap.has_action(interact_action):
		InputMap.add_action(interact_action)
		# Add 'E' key as default interact key
		var event := InputEventKey.new()
		event.keycode = KEY_E
		InputMap.action_add_event(interact_action, event)
		# Add 'F' key as alternative
		var event_f := InputEventKey.new()
		event_f.keycode = KEY_F
		InputMap.action_add_event(interact_action, event_f)

	_actions_initialized = true

func process_tick(_delta: float) -> void:
	if _manager == null:
		return

	_ensure_interact_action()

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
