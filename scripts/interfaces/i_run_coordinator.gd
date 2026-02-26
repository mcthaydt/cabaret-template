extends Node
class_name I_RunCoordinator

## Minimal interface for M_RunCoordinatorManager
##
## Implementations:
## - M_RunCoordinatorManager (production)

func is_reset_in_flight() -> bool:
	push_error("I_RunCoordinator.is_reset_in_flight not implemented")
	return false
