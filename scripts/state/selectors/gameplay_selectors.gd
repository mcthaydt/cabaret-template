extends RefCounted
class_name GameplaySelectors

## Gameplay state slice selectors
##
## Selectors are pure functions that compute derived state.
## Pass full state or slice state from M_StateStore.get_state() or M_StateStore.get_slice().
## Selectors should never mutate state - they only read and compute.

## Check if player is alive based on health
## Returns true if health > 0, false otherwise
static func get_is_player_alive(gameplay_state: Dictionary) -> bool:
	var health: int = gameplay_state.get("health", 0)
	return health > 0

## Check if game is over
## Returns true if player is dead OR game_over flag is set
static func get_is_game_over(gameplay_state: Dictionary) -> bool:
	# Check explicit game_over flag first
	if gameplay_state.has("game_over"):
		return gameplay_state.get("game_over", false)
	
	# Fall back to health check
	return not get_is_player_alive(gameplay_state)

## Calculate game completion percentage
## Returns 0.0-1.0 based on level progress (level/max_levels)
## Returns 0.0 if no max_levels data available
static func get_completion_percentage(gameplay_state: Dictionary) -> float:
	var max_levels: int = gameplay_state.get("max_levels", 0)
	
	# No objectives data available
	if max_levels <= 0:
		return 0.0
	
	var current_level: int = gameplay_state.get("level", 1)
	var completion: float = float(current_level) / float(max_levels)
	
	# Clamp to 0.0-1.0 range
	return clampf(completion, 0.0, 1.0)
