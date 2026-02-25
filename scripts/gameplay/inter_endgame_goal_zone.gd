extends "res://scripts/gameplay/inter_victory_zone.gd"
class_name Inter_EndgameGoalZone

const RS_ENDGAME_GOAL_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_endgame_goal_interaction_config.gd")
const DEBUG_VICTORY_TRACE := false

## Exterior final goal controller built on the victory interactable base.
##
## Keeps the GAME_COMPLETE goal zone hidden/disabled until the
## required area has been completed. Subscribes to the gameplay state
## and toggles visuals + Area3D monitoring accordingly.

var _store: I_StateStore = null
var _has_applied_state: bool = false
var _is_unlocked: bool = false
var _cached_endgame_config: RS_EndgameGoalInteractionConfig = null

func _debug_log(message: String) -> void:
	if not DEBUG_VICTORY_TRACE:
		return
	print("[VictoryDebug][Inter_EndgameGoalZone] %s" % message)

func _ready() -> void:
	super._ready()
	await get_tree().process_frame

	_store = U_StateUtils.get_store(self)
	if _store != null:
		_store.slice_updated.connect(_on_slice_updated)
	_refresh_lock_state()

func _exit_tree() -> void:
	if _store != null and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)
	super._exit_tree()

func _on_slice_updated(slice_name: StringName, __slice_state: Dictionary) -> void:
	if slice_name != StringName("gameplay"):
		return
	_refresh_lock_state()

func _refresh_lock_state() -> void:
	var unlocked: bool = false
	if _store != null:
		var state: Dictionary = _store.get_state()
		var gameplay: Dictionary = state.get("gameplay", {})
		var completed_raw: Variant = gameplay.get("completed_areas", [])
		if completed_raw is Array:
			var completed: Array = completed_raw
			unlocked = completed.has(_get_effective_required_area())
			_debug_log(
				"refresh_lock_state required_area=%s completed_areas=%s unlocked=%s"
				% [_get_effective_required_area(), str(completed), str(unlocked)]
			)
		else:
			_debug_log("refresh_lock_state skipped: gameplay.completed_areas invalid type=%s" % str(completed_raw))
	else:
		_debug_log("refresh_lock_state skipped: no store")

	_apply_lock_state(unlocked)

func _apply_lock_state(unlocked: bool) -> void:
	if _has_applied_state and _is_unlocked == unlocked:
		return

	_has_applied_state = true
	_is_unlocked = unlocked

	set_enabled(unlocked)
	visible = unlocked
	_debug_log("apply_lock_state unlocked=%s visible=%s enabled=%s" % [str(unlocked), str(visible), str(is_enabled())])

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
