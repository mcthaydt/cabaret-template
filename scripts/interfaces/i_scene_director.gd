extends Node
class_name I_SceneDirector

## Minimal interface for M_SceneDirectorManager
##
## Implementations:
## - M_SceneDirectorManager (production)

func get_active_directive_id() -> StringName:
	push_error("I_SceneDirector.get_active_directive_id not implemented")
	return StringName("")
