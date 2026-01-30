extends RefCounted
class_name U_AudioUtils

## Audio utility functions for typed audio manager access
##
## Phase 5: Created to provide type-safe access to audio manager via interface

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const I_AUDIO_MANAGER := preload("res://scripts/interfaces/i_audio_manager.gd")

## Get the audio manager instance via ServiceLocator
##
## Returns the registered audio manager or null if not found.
## Uses ServiceLocator for fast O(1) lookup without group traversal.
##
## @return I_AudioManager instance or null
static func get_audio_manager() -> I_AUDIO_MANAGER:
	var manager := U_SERVICE_LOCATOR.try_get_service(StringName("audio_manager"))
	if manager != null and manager is I_AUDIO_MANAGER:
		return manager as I_AUDIO_MANAGER
	return null
