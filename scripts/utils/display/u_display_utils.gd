extends RefCounted
class_name U_DisplayUtils

## Display utility functions for typed display manager access.

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const I_DISPLAY_MANAGER := preload("res://scripts/interfaces/i_display_manager.gd")

## Get the display manager instance via ServiceLocator.
##
## Returns the registered display manager or null if not found.
##
## @return I_DisplayManager instance or null
static func get_display_manager() -> I_DISPLAY_MANAGER:
	var manager := U_SERVICE_LOCATOR.try_get_service(StringName("display_manager"))
	if manager != null and manager is I_DISPLAY_MANAGER:
		return manager as I_DISPLAY_MANAGER
	return null
