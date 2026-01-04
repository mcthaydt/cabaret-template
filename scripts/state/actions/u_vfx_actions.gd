extends RefCounted
class_name U_VFXActions

## VFX Actions (Phase 0 - Task 0.4)
##
## Action creators for VFX slice mutations. All actions are registered with
## U_ActionRegistry for validation and dispatched via M_StateStore.

const U_ActionRegistry := preload("res://scripts/state/utils/u_action_registry.gd")

const ACTION_SET_SCREEN_SHAKE_ENABLED := StringName("vfx/set_screen_shake_enabled")
const ACTION_SET_SCREEN_SHAKE_INTENSITY := StringName("vfx/set_screen_shake_intensity")
const ACTION_SET_DAMAGE_FLASH_ENABLED := StringName("vfx/set_damage_flash_enabled")
const ACTION_SET_PARTICLES_ENABLED := StringName("vfx/set_particles_enabled")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_SET_SCREEN_SHAKE_ENABLED)
	U_ActionRegistry.register_action(ACTION_SET_SCREEN_SHAKE_INTENSITY)
	U_ActionRegistry.register_action(ACTION_SET_DAMAGE_FLASH_ENABLED)
	U_ActionRegistry.register_action(ACTION_SET_PARTICLES_ENABLED)

## Enable or disable screen shake effect
static func set_screen_shake_enabled(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_SCREEN_SHAKE_ENABLED,
		"payload": {
			"enabled": enabled
		},
		"immediate": true
	}

## Set screen shake intensity (clamped to 0.0-2.0)
static func set_screen_shake_intensity(intensity: float) -> Dictionary:
	return {
		"type": ACTION_SET_SCREEN_SHAKE_INTENSITY,
		"payload": {
			"intensity": intensity
		},
		"immediate": true
	}

## Enable or disable damage flash effect
static func set_damage_flash_enabled(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_DAMAGE_FLASH_ENABLED,
		"payload": {
			"enabled": enabled
		},
		"immediate": true
	}

## Enable or disable particle effects
static func set_particles_enabled(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_PARTICLES_ENABLED,
		"payload": {
			"enabled": enabled
		},
		"immediate": true
	}
