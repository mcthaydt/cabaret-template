extends "res://scripts/gameplay/base_interactable_controller.gd"
class_name TriggeredInteractableController

const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_InteractBlocker := preload("res://scripts/utils/u_interact_blocker.gd")

enum TriggerMode {
	AUTO = 0,
	INTERACT = 1,
}

const PROMPT_SHOW_EVENT := StringName("interact_prompt_show")
const PROMPT_HIDE_EVENT := StringName("interact_prompt_hide")

var _trigger_mode: TriggerMode = TriggerMode.AUTO
@export var trigger_mode: TriggerMode:
	get:
		return _trigger_mode
	set(value):
		if _trigger_mode == value:
			return
		_trigger_mode = value
		if _trigger_mode != TriggerMode.INTERACT:
			_hide_interact_prompt()

@export var interact_action: StringName = StringName("interact")
@export var interact_prompt: String = "Interact"

var _active_prompt_shown: bool = false
var _active_prompt_controller_id: int = 0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _trigger_mode != TriggerMode.INTERACT:
		return
	if interact_action.is_empty():
		return
	if not is_player_in_zone():
		return
	# Block interact input during toast display + cooldown
	if U_InteractBlocker.is_blocked():
		return
	var action_name := String(interact_action)
	if not InputMap.has_action(action_name):
		return
	if not Input.is_action_just_pressed(action_name):
		return
	var player := get_primary_player()
	if player == null:
		return
	activate(player)

func _on_player_entered(player: Node3D) -> void:
	if _trigger_mode == TriggerMode.AUTO:
		activate(player)
	else:
		_show_interact_prompt()
	super._on_player_entered(player)

func _on_player_exited(player: Node3D) -> void:
	_hide_interact_prompt()
	super._on_player_exited(player)

func _on_enabled_state_changed(enabled: bool) -> void:
	super._on_enabled_state_changed(enabled)
	if not enabled:
		_hide_interact_prompt()

func _exit_tree() -> void:
	_hide_interact_prompt()
	super._exit_tree()

func _show_interact_prompt() -> void:
	if _trigger_mode != TriggerMode.INTERACT:
		return
	if _active_prompt_shown:
		return
	if interact_action.is_empty():
		return
	# Do not show prompts while transitions/overlays are active (pause/menus)
	if _is_transition_blocked():
		return

	var payload := {
		"controller_id": get_instance_id(),
		"action": interact_action,
		"prompt": interact_prompt
	}
	U_ECSEventBus.publish(PROMPT_SHOW_EVENT, payload)
	_active_prompt_shown = true
	_active_prompt_controller_id = get_instance_id()

func _hide_interact_prompt() -> void:
	if not _active_prompt_shown:
		return
	var payload := {
		"controller_id": _active_prompt_controller_id
	}
	U_ECSEventBus.publish(PROMPT_HIDE_EVENT, payload)
	_active_prompt_shown = false
	_active_prompt_controller_id = 0
