extends Node
class_name U_VisualActions

## Visual/audio action creators for gameplay slice
##
## Phase 16: Created for full project integration
## Used by visual/audio systems to dispatch settings changes

const ActionRegistry = preload("res://scripts/state/utils/u_action_registry.gd")

## Toggle landing indicator visibility
static func toggle_landing_indicator(visible: bool) -> Dictionary:
	return U_ActionRegistry.create_action("gameplay/TOGGLE_LANDING_INDICATOR", {
		"show_landing_indicator": visible
	})

## Update particle settings
static func update_particle_settings(settings: Dictionary) -> Dictionary:
	return U_ActionRegistry.create_action("gameplay/UPDATE_PARTICLE_SETTINGS", {
		"particle_settings": settings
	})

## Update audio settings
static func update_audio_settings(settings: Dictionary) -> Dictionary:
	return U_ActionRegistry.create_action("gameplay/UPDATE_AUDIO_SETTINGS", {
		"audio_settings": settings
	})
