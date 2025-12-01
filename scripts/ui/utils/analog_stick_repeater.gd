extends RefCounted
class_name AnalogStickRepeater

## Handles analog stick repeat/echo behavior for UI navigation.
##
## Mimics keyboard key repeat: immediate trigger on press, delay before repeating,
## then continuous repeat at a fixed interval while held.

const REPEAT_INITIAL_DELAY: float = 0.8  # 800ms before first repeat
const REPEAT_INTERVAL: float = 0.05       # 50ms between repeats

## Callback invoked when navigation should occur
var on_navigate: Callable = func(_direction: StringName) -> void: pass

## State per direction
var _direction_states: Dictionary = {}  # StringName -> DirectionState


class DirectionState:
	var is_active: bool = false
	var time_held: float = 0.0
	var time_since_last_repeat: float = 0.0

func reset() -> void:
	_direction_states.clear()


## Update the repeater state for a given direction
##
## Call this every frame with the current stick state for each direction.
## @param direction: The ui_* action name (e.g., "ui_down")
## @param is_pressed: Whether the stick is currently above the deadzone in this direction
## @param delta: Time since last frame
func update(direction: StringName, is_pressed: bool, delta: float) -> void:
	# Get or create state for this direction
	var state: DirectionState = _direction_states.get(direction) as DirectionState
	if state == null:
		state = DirectionState.new()
		_direction_states[direction] = state

	# Handle release
	if not is_pressed:
		if state.is_active:
			state.is_active = false
			state.time_held = 0.0
			state.time_since_last_repeat = 0.0
		return

	# Handle initial press (immediate trigger)
	if not state.is_active:
		state.is_active = true
		state.time_held = 0.0
		state.time_since_last_repeat = 0.0
		_trigger_navigation(direction)
		return

	# Handle held state (repeat logic)
	state.time_held += delta
	state.time_since_last_repeat += delta

	# Wait for initial delay
	if state.time_held < REPEAT_INITIAL_DELAY:
		return

	# Check if it's time to repeat
	if state.time_since_last_repeat >= REPEAT_INTERVAL:
		_trigger_navigation(direction)
		state.time_since_last_repeat = 0.0


func _trigger_navigation(direction: StringName) -> void:
	if on_navigate.is_valid():
		on_navigate.call(direction)
