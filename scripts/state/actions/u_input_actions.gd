extends Node
class_name U_InputActions

## Input action creators for gameplay slice
##
## Phase 16: Created for full project integration
## Used by S_InputSystem to dispatch input state changes

const ActionRegistry = preload("res://scripts/state/action_registry.gd")

## Update move input (WASD or analog stick)
static func update_move_input(move_input: Vector2) -> Dictionary:
	return ActionRegistry.create_action("gameplay/UPDATE_MOVE_INPUT", {
		"move_input": move_input
	})

## Update look input (mouse or right stick)
static func update_look_input(look_input: Vector2) -> Dictionary:
	return ActionRegistry.create_action("gameplay/UPDATE_LOOK_INPUT", {
		"look_input": look_input
	})

## Update jump state (pressed, just_pressed)
static func update_jump_state(jump_pressed: bool, jump_just_pressed: bool) -> Dictionary:
	return ActionRegistry.create_action("gameplay/UPDATE_JUMP_STATE", {
		"jump_pressed": jump_pressed,
		"jump_just_pressed": jump_just_pressed
	})
