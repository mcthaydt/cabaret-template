extends "res://scripts/gameplay/inter_victory_zone.gd"
class_name Inter_EndgameGoalZone

const RS_ENDGAME_GOAL_INTERACTION_CONFIG := preload("res://scripts/core/resources/interactions/rs_endgame_goal_interaction_config.gd")
const DEBUG_VICTORY_TRACE := false

## Exterior final goal controller built on the victory interactable base.
##
## Keeps the GAME_COMPLETE goal zone hidden/disabled until the
## required area has been completed. Subscribes to the gameplay state
## and toggles visuals + Area3D monitoring accordingly.

var _cached_endgame_config: RS_EndgameGoalInteractionConfig = null

func _debug_log(message: String) -> void:
	if not DEBUG_VICTORY_TRACE:
		return
	print("[VictoryDebug][Inter_EndgameGoalZone] %s" % message)

func _is_slice_relevant_for_visibility_gate(slice_name: StringName) -> bool:
	if slice_name == StringName("gameplay"):
		return true
	return super._is_slice_relevant_for_visibility_gate(slice_name)

func _compute_visibility_gate_unlocked(state: Dictionary) -> bool:
	if not super._compute_visibility_gate_unlocked(state):
		return false

	var gameplay_variant: Variant = state.get("gameplay", {})
	if not (gameplay_variant is Dictionary):
		_debug_log("compute_visibility_gate locked: missing gameplay slice")
		return false
	var gameplay: Dictionary = gameplay_variant as Dictionary
	var completed_raw: Variant = gameplay.get("completed_areas", [])
	if not (completed_raw is Array):
		_debug_log("compute_visibility_gate locked: gameplay.completed_areas invalid type=%s" % str(completed_raw))
		return false
	var completed: Array = completed_raw
	var unlocked: bool = completed.has(_get_effective_required_area())
	_debug_log(
		"compute_visibility_gate required_area=%s completed_areas=%s unlocked=%s"
		% [_get_effective_required_area(), str(completed), str(unlocked)]
	)
	return unlocked

func _get_effective_required_area() -> String:
	var typed := _resolve_endgame_config()
	if typed != null:
		return typed.required_area
	return ""

func _resolve_endgame_config() -> RS_EndgameGoalInteractionConfig:
	if config == null:
		_cached_endgame_config = null
		return null
	if config != null and U_INTERACTION_CONFIG_RESOLVER.script_matches(config, RS_ENDGAME_GOAL_INTERACTION_CONFIG):
		_cached_endgame_config = config as RS_EndgameGoalInteractionConfig
	return _cached_endgame_config
