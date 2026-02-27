extends Resource
class_name I_Effect

## Interface for QB effect resources
##
## Implementations:
## - RS_BaseEffect (and all concrete effect subclasses)

func execute(_context: Dictionary) -> void:
	push_error("I_Effect.execute not implemented")
