extends Node
class_name I_SceneManager

## Interface for scene management
##
## Handles scene transitions, overlay stacks, and scene lifecycle.
## Manages the active scene container and UI overlay system.
##
## Phase: Duck Typing Cleanup Phase 3 (2026-01-22)
## Created to enable type-safe scene management and remove has_method() checks
##
## Implementations:
## - M_SceneManager (production)
## - MockSceneManagerWithTransition (testing)

## Check if a scene transition is currently in progress.
##
## @return bool: True if transitioning, false otherwise
func is_transitioning() -> bool:
	push_error("I_SceneManager.is_transitioning not implemented")
	return false

## Transition to a new scene with specified transition effect.
##
## @param scene_id: StringName identifying the target scene in the registry
## @param transition_type: String describing the transition effect (e.g., "fade", "instant")
## @param priority: int priority level for queueing (default: 0 = NORMAL)
func transition_to_scene(_scene_id: StringName, _transition_type: String = "fade", _priority: int = 0) -> void:
	push_error("I_SceneManager.transition_to_scene not implemented")

## Hint to the scene cache that a scene should be preloaded.
##
## @param scene_path: String resource path to the .tscn file
func hint_preload_scene(_scene_path: String) -> void:
	push_error("I_SceneManager.hint_preload_scene not implemented")

## Suppress pause menu activation for the current frame.
##
## Used when auto-triggering scene transitions to prevent ESC key
## from opening pause menu on the same frame.
func suppress_pause_for_current_frame() -> void:
	push_error("I_SceneManager.suppress_pause_for_current_frame not implemented")

## Push an overlay scene onto the overlay stack.
##
## @param scene_id: StringName identifying the overlay scene
## @param force: bool whether to force push even if already on stack
func push_overlay(_scene_id: StringName, _force: bool = false) -> void:
	push_error("I_SceneManager.push_overlay not implemented")

## Pop the top overlay scene from the overlay stack.
func pop_overlay() -> void:
	push_error("I_SceneManager.pop_overlay not implemented")

## Register HUD controller for transition coordination
##
## @param hud: CanvasLayer HUD controller to register
func register_hud_controller(_hud: CanvasLayer) -> void:
	push_error("I_SceneManager.register_hud_controller not implemented")

## Unregister HUD controller
##
## @param hud: Optional CanvasLayer to unregister (null = unregister current)
func unregister_hud_controller(_hud: CanvasLayer = null) -> void:
	push_error("I_SceneManager.unregister_hud_controller not implemented")

## Get the registered HUD controller
##
## @return CanvasLayer: Current HUD controller, or null if none registered
func get_hud_controller() -> CanvasLayer:
	push_error("I_SceneManager.get_hud_controller not implemented")
	return null
