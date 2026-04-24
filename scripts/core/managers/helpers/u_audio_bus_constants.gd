class_name U_AudioBusConstants

## Audio Bus Constants and Validation
##
## Defines required audio bus names and provides validation utilities.
## Buses should be defined in Project Settings → Audio → Buses.

# Bus name constants
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const BUS_FOOTSTEPS := "Footsteps"
const BUS_AMBIENT := "Ambient"

# Required bus hierarchy:
# Master (0)
# ├── Music (1)
# ├── SFX (2)
# │   ├── UI (3)
# │   └── Footsteps (4)
# └── Ambient (5)
const REQUIRED_BUSES: Array[StringName] = [
	StringName("Master"),
	StringName("Music"),
	StringName("SFX"),
	StringName("UI"),
	StringName("Footsteps"),
	StringName("Ambient")
]

## Validates that all required buses exist in the audio bus layout.
## Returns true if all buses are present, false otherwise.
## If log_warnings is true, logs warnings for any missing buses.
static func validate_bus_layout(log_warnings: bool = true) -> bool:
	var all_present := true
	for bus_name in REQUIRED_BUSES:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index == -1:
			if log_warnings:
				push_warning("U_AudioBusConstants: Required audio bus '%s' is missing" % bus_name)
			all_present = false
	return all_present

## Gets the bus index for a given bus name with safe fallback.
## Returns the bus index if found, otherwise returns 0 (Master bus).
## If log_warning is true, logs a warning when falling back to Master.
static func get_bus_index_safe(bus_name: StringName, log_warning: bool = true) -> int:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		if log_warning:
			push_warning("U_AudioBusConstants: Bus '%s' not found, falling back to Master" % bus_name)
		return 0
	return bus_index
