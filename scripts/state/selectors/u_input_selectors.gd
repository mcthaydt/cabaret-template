extends RefCounted
class_name U_InputSelectors

## Input state selectors for gameplay slice
##
## Phase 16: Created for full project integration
## Used by input-driven systems to read state

## Get move input (WASD or analog stick)
static func get_move_input(state: Dictionary) -> Vector2:
	return state.get("gameplay", {}).get("move_input", Vector2.ZERO)

## Get look input (mouse or right stick)
static func get_look_input(state: Dictionary) -> Vector2:
	return state.get("gameplay", {}).get("look_input", Vector2.ZERO)

## Get jump pressed state
static func get_is_jump_pressed(state: Dictionary) -> bool:
	return state.get("gameplay", {}).get("jump_pressed", false)

## Get jump just pressed state
static func get_is_jump_just_pressed(state: Dictionary) -> bool:
	return state.get("gameplay", {}).get("jump_just_pressed", false)
