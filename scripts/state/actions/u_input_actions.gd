extends RefCounted
class_name U_InputActions

## Input action creators for gameplay slice
##
## Phase 16: Created for full project integration
## Used by S_InputSystem to dispatch input state changes

const ACTION_UPDATE_MOVE_INPUT := StringName("gameplay/UPDATE_MOVE_INPUT")
const ACTION_UPDATE_LOOK_INPUT := StringName("gameplay/UPDATE_LOOK_INPUT")
const ACTION_UPDATE_JUMP_STATE := StringName("gameplay/UPDATE_JUMP_STATE")

## Static initializer - register actions
static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_UPDATE_MOVE_INPUT)
	U_ActionRegistry.register_action(ACTION_UPDATE_LOOK_INPUT)
	U_ActionRegistry.register_action(ACTION_UPDATE_JUMP_STATE)

## Update move input (WASD or analog stick)
static func update_move_input(move_input: Vector2) -> Dictionary:
	return {
		"type": ACTION_UPDATE_MOVE_INPUT,
		"payload": {
			"move_input": move_input
		}
	}

## Update look input (mouse or right stick)
static func update_look_input(look_input: Vector2) -> Dictionary:
	return {
		"type": ACTION_UPDATE_LOOK_INPUT,
		"payload": {
			"look_input": look_input
		}
	}

## Update jump state (pressed, just_pressed)
static func update_jump_state(jump_pressed: bool, jump_just_pressed: bool) -> Dictionary:
	return {
		"type": ACTION_UPDATE_JUMP_STATE,
		"payload": {
			"jump_pressed": jump_pressed,
			"jump_just_pressed": jump_just_pressed
		}
	}
