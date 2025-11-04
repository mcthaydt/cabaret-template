extends RefCounted
class_name BaseSpawnEffect

## Base Spawn Effect (Phase 12.4 - T270)
##
## Base class for spawn visual effects (fade, particles, etc.).
## Effects are optional polish that enhance spawn transitions.
##
## Usage:
##   var effect := SpawnFadeEffect.new()
##   effect.execute(player, completion_callback)
##
## Subclasses must override:
##   - execute(target: Node, callback: Callable)

## Duration of effect in seconds
var duration: float = 0.3

## Execute spawn effect on target node
##
## Parameters:
##   target: Node to apply effect to (player, spawn point, etc.)
##   completion_callback: Called when effect finishes
##
## Subclasses should override this method to implement effect logic.
func execute(target: Node, completion_callback: Callable) -> void:
	# Base implementation: just call callback immediately
	if completion_callback.is_valid():
		completion_callback.call()
