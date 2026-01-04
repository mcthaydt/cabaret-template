extends RefCounted
class_name U_VFXSelectors

## VFX Selectors (Phase 0 - Task 0.6)
##
## Pure selector functions for reading VFX slice state. Provides safe defaults
## when vfx slice or fields are missing.

## Returns whether screen shake effect is enabled
## Defaults to true if vfx slice or field is missing
static func is_screen_shake_enabled(state: Dictionary) -> bool:
	var vfx: Dictionary = state.get("vfx", {})
	return bool(vfx.get("screen_shake_enabled", true))

## Returns screen shake intensity (0.0-2.0 range)
## Defaults to 1.0 if vfx slice or field is missing
static func get_screen_shake_intensity(state: Dictionary) -> float:
	var vfx: Dictionary = state.get("vfx", {})
	return float(vfx.get("screen_shake_intensity", 1.0))

## Returns whether damage flash effect is enabled
## Defaults to true if vfx slice or field is missing
static func is_damage_flash_enabled(state: Dictionary) -> bool:
	var vfx: Dictionary = state.get("vfx", {})
	return bool(vfx.get("damage_flash_enabled", true))

## Returns whether particle effects are enabled
## Defaults to true if vfx slice or field is missing
static func is_particles_enabled(state: Dictionary) -> bool:
	var vfx: Dictionary = state.get("vfx", {})
	return bool(vfx.get("particles_enabled", true))
