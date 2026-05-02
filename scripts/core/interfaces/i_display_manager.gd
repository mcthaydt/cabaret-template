extends Node
class_name I_DisplayManager

## Minimal interface for M_DisplayManager
##
## Phase 1A: Created for display manager duck typing + testing.
##
## Implementations:
## - M_DisplayManager (production)
## - MockDisplayManager (testing)

## Set temporary display settings preview
##
## Applies temporary display settings for preview purposes (e.g., settings menu).
## Preview settings override Redux state until cleared.
##
## @param _settings: Dictionary with display settings overrides
func set_display_settings_preview(_settings: Dictionary) -> void:
	push_error("I_DisplayManager.set_display_settings_preview not implemented")

## Clear display settings preview
##
## Removes temporary preview settings and restores display state from Redux store.
func clear_display_settings_preview() -> void:
	push_error("I_DisplayManager.clear_display_settings_preview not implemented")

## Register a UI scale root for display scaling.
##
## @param _node: CanvasLayer/Control/Node2D root to scale
func register_ui_scale_root(_node: Node) -> void:
	push_error("I_DisplayManager.register_ui_scale_root not implemented")

## Unregister a UI scale root.
##
## @param _node: CanvasLayer/Control/Node2D root to stop scaling
func unregister_ui_scale_root(_node: Node) -> void:
	push_error("I_DisplayManager.unregister_ui_scale_root not implemented")

## Get the currently active UI color palette
##
## Returns the palette resource used for accessibility color adjustments.
func get_active_palette() -> Resource:
	push_error("I_DisplayManager.get_active_palette not implemented")
	return null
