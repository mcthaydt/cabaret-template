extends RefCounted
class_name U_GameplaySelectors

## Gameplay state slice selectors
##
## Selectors are pure functions that compute derived state.
## Pass full state or slice state from M_StateStore.get_state() or M_StateStore.get_slice().
## Selectors should never mutate state - they only read and compute.

## Get whether game is currently paused
static func get_is_paused(gameplay_state: Dictionary) -> bool:
	return gameplay_state.get("paused", false)
