extends Resource
class_name I_Condition

## Interface for QB condition resources
##
## Implementations:
## - RS_BaseCondition (and all concrete condition subclasses)

func evaluate(_context: Dictionary) -> float:
	push_error("I_Condition.evaluate not implemented")
	return 0.0
