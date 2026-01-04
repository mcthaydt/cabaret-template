class_name RS_VFXInitialState
extends Resource

## VFX Initial State Resource (Phase 0 - Task 0.2)
##
## Defines default VFX settings that can be configured per-scene or per-save slot.
## The state store merges these values with reducer defaults to create the initial
## vfx slice state.

@export_group("Screen Shake")
@export var screen_shake_enabled: bool = true
@export_range(0.0, 2.0, 0.1) var screen_shake_intensity: float = 1.0

@export_group("Damage Flash")
@export var damage_flash_enabled: bool = true

@export_group("Particles")
@export var particles_enabled: bool = true

## Converts this resource to a dictionary for merging with reducer defaults
func to_dictionary() -> Dictionary:
	return {
		"screen_shake_enabled": screen_shake_enabled,
		"screen_shake_intensity": screen_shake_intensity,
		"damage_flash_enabled": damage_flash_enabled,
		"particles_enabled": particles_enabled
	}
