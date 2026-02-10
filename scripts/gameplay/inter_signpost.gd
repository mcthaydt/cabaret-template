extends "res://scripts/gameplay/triggered_interactable_controller.gd"
class_name Inter_Signpost

const SIGNPOST_MESSAGE_EVENT := StringName("signpost_message")
const RS_SIGNPOST_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_signpost_interaction_config.gd")
const U_INTERACTION_CONFIG_RESOLVER := preload("res://scripts/gameplay/helpers/u_interaction_config_resolver.gd")

signal signpost_activated(message: String, signpost: Inter_Signpost)

var _config: Resource = null
@export var config: Resource:
	get:
		return _config
	set(value):
		_config = value
		_apply_config_resource()

@export var message: String = ""
@export var repeatable: bool = true

func _init() -> void:
	trigger_mode = TriggerMode.INTERACT
	cooldown_duration = 0.0
	interact_prompt = "Read"

func _ready() -> void:
	_apply_config_resource()
	super._ready()
	# Ensure signposts remain interact-only regardless of inspector tweaks.
	trigger_mode = TriggerMode.INTERACT

func _on_activated(player: Node3D) -> void:
	var effective_message := _get_effective_message()
	var effective_repeatable := _get_effective_repeatable()
	signpost_activated.emit(effective_message, self)
	U_ECSEventBus.publish(SIGNPOST_MESSAGE_EVENT, {
		"message": effective_message,
		"controller_id": get_instance_id(),
		"repeatable": effective_repeatable
	})
	if not effective_repeatable:
		lock()
		_hide_interact_prompt()
	super._on_activated(player)

func _apply_config_resource() -> void:
	var typed := _resolve_config()
	if typed == null:
		return

	interact_prompt = U_INTERACTION_CONFIG_RESOLVER.as_string(
		typed.get("interact_prompt"),
		interact_prompt
	)

func _resolve_config() -> Resource:
	if _config == null:
		return null
	if U_INTERACTION_CONFIG_RESOLVER.script_matches(_config, RS_SIGNPOST_INTERACTION_CONFIG):
		return _config
	return null

func _get_effective_message() -> String:
	var typed := _resolve_config()
	if typed != null:
		return U_INTERACTION_CONFIG_RESOLVER.as_string(typed.get("message"), message)
	return message

func _get_effective_repeatable() -> bool:
	var typed := _resolve_config()
	if typed != null:
		return U_INTERACTION_CONFIG_RESOLVER.as_bool(typed.get("repeatable"), repeatable)
	return repeatable
