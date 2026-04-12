extends RefCounted
class_name U_GameplaySelectors

## Gameplay state slice selectors
##
## Selectors are pure functions that compute derived state.
## Pass full state from M_StateStore.get_state() or a gameplay slice.
## Selectors should never mutate state - they only read and compute.

## Get whether game is currently paused
static func get_is_paused(state: Dictionary) -> bool:
	return _get_gameplay_slice(state).get("paused", false)

## Get the last activated checkpoint spawn point ID
static func get_last_checkpoint(state: Dictionary) -> StringName:
	return _get_gameplay_slice(state).get("last_checkpoint", StringName(""))

## Get whether touchscreen drag-look is actively driving look input.
static func is_touch_look_active(state: Dictionary) -> bool:
	return bool(_get_gameplay_slice(state).get("touch_look_active", false))

## Get total playtime in seconds
static func get_playtime_seconds(state: Dictionary) -> int:
	return int(_get_gameplay_slice(state).get("playtime_seconds", 0))

## Get the target spawn point for area transitions
static func get_target_spawn_point(state: Dictionary) -> StringName:
	return _get_gameplay_slice(state).get("target_spawn_point", StringName(""))

## Get whether a death sequence is in progress (blocks autosave)
static func is_death_in_progress(state: Dictionary) -> bool:
	return bool(_get_gameplay_slice(state).get("death_in_progress", false))

## Get AI demo flags dictionary
static func get_ai_demo_flags(state: Dictionary) -> Dictionary:
	var flags: Variant = _get_gameplay_slice(state).get("ai_demo_flags", {})
	if flags is Dictionary:
		return flags as Dictionary
	return {}

## Get the last victory objective ID
static func get_last_victory_objective(state: Dictionary) -> StringName:
	return _get_gameplay_slice(state).get("last_victory_objective", StringName(""))

## Get player health from gameplay slice
static func get_player_health(state: Dictionary) -> float:
	return float(_get_gameplay_slice(state).get("player_health", 0.0))

## Get player max health from gameplay slice
static func get_player_max_health(state: Dictionary) -> float:
	return float(_get_gameplay_slice(state).get("player_max_health", 0.0))

## Get entity snapshots dictionary from gameplay slice
static func get_entities(state: Dictionary) -> Dictionary:
	var entities: Variant = _get_gameplay_slice(state).get("entities", {})
	if entities is Dictionary:
		return entities as Dictionary
	return {}

## Get completed area IDs
static func get_completed_areas(state: Dictionary) -> Array:
	var areas: Variant = _get_gameplay_slice(state).get("completed_areas", [])
	if areas is Array:
		return (areas as Array).duplicate(true)
	return []

## Get whether the game has been completed (all required areas done)
static func get_game_completed(state: Dictionary) -> bool:
	return bool(_get_gameplay_slice(state).get("game_completed", false))

## Get total death count
static func get_death_count(state: Dictionary) -> int:
	return int(_get_gameplay_slice(state).get("death_count", 0))

## Private: extract gameplay slice from full state
static func _get_gameplay_slice(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	# If state has a "gameplay" key, extract the nested slice (full state passed)
	var gameplay: Variant = state.get("gameplay", null)
	if gameplay is Dictionary:
		return gameplay as Dictionary
	# If state has "paused" key, it's already the gameplay slice (backward compat)
	if state.has("paused"):
		return state
	return {}
