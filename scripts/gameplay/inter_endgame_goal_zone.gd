extends "res://scripts/gameplay/inter_victory_zone.gd"
class_name Inter_EndgameGoalZone

const RS_ENDGAME_GOAL_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_endgame_goal_interaction_config.gd")

## Exterior final goal controller built on the victory interactable base.
##
## Keeps the GAME_COMPLETE goal zone hidden/disabled until the
## required area has been completed. Subscribes to the gameplay state
## and toggles visuals + Area3D monitoring accordingly.


@export var required_area: String = "interior_house"

var _store: I_StateStore = null
var _has_applied_state: bool = false
var _is_unlocked: bool = false

func _ready() -> void:
	super._ready()
	await get_tree().process_frame

	_store = U_StateUtils.get_store(self)
	if _store != null:
		_store.slice_updated.connect(_on_slice_updated)

	victory_type = C_VictoryTriggerComponent.VictoryType.GAME_COMPLETE
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

	_apply_lock_state(unlocked)

func _apply_lock_state(unlocked: bool) -> void:
	if _has_applied_state and _is_unlocked == unlocked:
		return

	_has_applied_state = true
	_is_unlocked = unlocked

	set_enabled(unlocked)
	visible = unlocked

func _get_effective_required_area() -> String:
	var typed := _resolve_endgame_config()
	if typed != null:
		return U_INTERACTION_CONFIG_RESOLVER.as_string(typed.get("required_area"), required_area)
	return required_area

func _resolve_endgame_config() -> Resource:
	if config == null:
		return null
	if U_INTERACTION_CONFIG_RESOLVER.script_matches(config, RS_ENDGAME_GOAL_INTERACTION_CONFIG):
		return config
	return null
