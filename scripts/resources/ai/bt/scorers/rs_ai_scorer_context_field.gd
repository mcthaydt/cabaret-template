@icon("res://assets/editor_icons/icn_resource.svg")
extends "res://scripts/resources/ai/bt/scorers/rs_ai_scorer.gd"
class_name RS_AIScorerContextField

const U_PATH_RESOLVER := preload("res://scripts/utils/qb/u_path_resolver.gd")

@export var path: String = ""
@export var multiplier: float = 1.0

func score(context: Dictionary) -> float:
	if path.is_empty():
		push_error("RS_AIScorerContextField.score: path is empty")
		return 0.0

	var resolved_value: Variant = U_PATH_RESOLVER.resolve(context, path)
	if resolved_value == null:
		push_error("RS_AIScorerContextField.score: unable to resolve path '%s'" % path)
		return 0.0

	if resolved_value is float or resolved_value is int:
		return float(resolved_value) * multiplier

	push_error("RS_AIScorerContextField.score: resolved value at path '%s' is non-numeric" % path)
	return 0.0
