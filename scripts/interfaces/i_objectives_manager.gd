extends Node
class_name I_ObjectivesManager

## Minimal interface for M_ObjectivesManager
##
## Implementations:
## - M_ObjectivesManager (production)

func load_objective_set(_set_id: StringName) -> bool:
	push_error("I_ObjectivesManager.load_objective_set not implemented")
	return false

func unload_objective_set(_set_id: StringName) -> bool:
	push_error("I_ObjectivesManager.unload_objective_set not implemented")
	return false

func reset_for_new_run(_set_id: StringName = StringName("default_progression")) -> bool:
	push_error("I_ObjectivesManager.reset_for_new_run not implemented")
	return false

func get_objective_status(_objective_id: StringName) -> String:
	push_error("I_ObjectivesManager.get_objective_status not implemented")
	return ""
