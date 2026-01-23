extends Node
class_name I_VFXManager

## Interface for VFX Manager implementations
## Phase 8 (Duck Typing Cleanup): Created to replace has_method() checks with explicit typing
## Implementations: M_VFXManager

## Get the effects container node
func get_effects_container() -> Node:
	push_error("I_VFXManager.get_effects_container not implemented")
	return null

## Set the effects container node
func set_effects_container(_container: Node) -> void:
	push_error("I_VFXManager.set_effects_container not implemented")

## Apply temporary preview settings (for UI testing)
func set_vfx_settings_preview(_settings: Dictionary) -> void:
	push_error("I_VFXManager.set_vfx_settings_preview not implemented")

## Clear preview and revert to Redux state
func clear_vfx_settings_preview() -> void:
	push_error("I_VFXManager.clear_vfx_settings_preview not implemented")

## Trigger a test shake for preview purposes
func trigger_test_shake(_intensity: float = 1.0) -> void:
	push_error("I_VFXManager.trigger_test_shake not implemented")
