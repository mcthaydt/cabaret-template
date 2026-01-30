@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_PlaytimeSystem

## Playtime Tracking System (Phase 0: Save Manager)
##
## Tracks total gameplay time and updates the playtime_seconds field in state.
## Pauses tracking when:
## - Navigation shell is not "gameplay"
## - Game is paused
## - Scene is transitioning
##
## Implementation:
## - Tracks elapsed time as float internally to prevent precision loss
## - Dispatches whole seconds only via increment_playtime action
## - Carries sub-second remainder across frames

const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_NAVIGATION_SELECTORS := preload("res://scripts/state/selectors/u_navigation_selectors.gd")

## Injected state store (for testing)
## If set, system uses this instead of U_StateUtils.get_store()
@export var state_store: I_StateStore = null

var _store: I_StateStore = null
var _accumulated_time: float = 0.0

func _ready() -> void:
	# Set priority (playtime tracking is low priority, doesn't affect gameplay)
	execution_priority = 200
	super._ready()

func on_configured() -> void:
	# Use injected store if available, otherwise get from service locator
	if state_store != null:
		_store = state_store
	else:
		_store = U_STATE_UTILS.get_store(self)

func process_tick(delta: float) -> void:
	if _store == null:
		return

	# Check if we should be tracking playtime
	if not _should_track_playtime():
		return

	# Accumulate time
	_accumulated_time += delta

	# Only dispatch when we've accumulated at least 1 full second
	if _accumulated_time >= 1.0:
		var whole_seconds: int = int(_accumulated_time)
		_accumulated_time -= float(whole_seconds)  # Carry remainder to next frame

		var action: Dictionary = U_GAMEPLAY_ACTIONS.increment_playtime(whole_seconds)
		_store.dispatch(action)

## Check if playtime tracking should be active
func _should_track_playtime() -> bool:
	if _store == null:
		return false

	var state: Dictionary = _store.get_state()
	var navigation: Dictionary = state.get("navigation", {})
	var scene: Dictionary = state.get("scene", {})

	# Don't track if not in gameplay shell
	if navigation.get("shell", "") != "gameplay":
		return false

	# Don't track if game is paused (overlay_stack not empty)
	# U_NavigationSelectors expect navigation SLICE, not full state
	if U_NAVIGATION_SELECTORS.is_paused(navigation):
		return false

	# Don't track if scene is transitioning
	if scene.get("is_transitioning", false):
		return false

	return true
