class_name I_TransitionEffect
extends RefCounted

## I_TransitionEffect - Interface for scene transition effects
##
## Phase 10B-2 (T136a): Defines contract for all transition implementations
##
## All transition effects (fade, loading, instant, etc.) should implement these methods
## to ensure consistent lifecycle and behavior across different transition types.
##
## Lifecycle:
##   1. initialize(config) - Setup effect with configuration
##   2. execute(layer, callback) - Run transition animation
##   3. on_scene_swap() - Hook called when scene swap occurs (mid-transition)
##   4. on_complete() - Hook called when transition finishes
##
## Usage:
##   class Trans_Fade extends I_TransitionEffect:
##       func initialize(config: Dictionary) -> void:
##           # Setup fade parameters
##       func execute(layer: CanvasLayer, callback: Callable) -> void:
##           # Run fade animation

## Initialize the transition effect with configuration
##
## Parameters:
##   config: Dictionary with transition-specific settings
##     - duration: float - Transition duration in seconds
##     - color: Color - Fade color (for fade transitions)
##     - etc.
##
func initialize(_config: Dictionary) -> void:
	push_error("I_TransitionEffect.initialize() must be implemented by subclass")

## Execute the transition effect
##
## Parameters:
##   layer: CanvasLayer - Canvas layer to render transition on
##   callback: Callable - Called when transition completes
##
func execute(_layer: CanvasLayer, callback: Callable) -> void:
	push_error("I_TransitionEffect.execute() must be implemented by subclass")
	if callback != null and callback.is_valid():
		callback.call()

## Hook called when scene swap should occur (mid-transition)
## Override this in transitions that need to coordinate scene swap timing
func on_scene_swap() -> void:
	# Optional override - default implementation does nothing
	pass

## Hook called when transition completes
## Override this for cleanup or final state adjustments
func on_complete() -> void:
	# Optional override - default implementation does nothing
	pass
