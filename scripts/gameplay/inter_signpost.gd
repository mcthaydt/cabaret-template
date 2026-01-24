extends "res://scripts/gameplay/triggered_interactable_controller.gd"
class_name Inter_Signpost

const SIGNPOST_MESSAGE_EVENT := StringName("signpost_message")

signal signpost_activated(message: String, signpost: Inter_Signpost)

@export var message: String = ""
@export var repeatable: bool = true

func _init() -> void:
	trigger_mode = TriggerMode.INTERACT
	cooldown_duration = 0.0
	interact_prompt = "Read"

func _ready() -> void:
	super._ready()
	# Ensure signposts remain interact-only regardless of inspector tweaks.
	trigger_mode = TriggerMode.INTERACT

func _on_activated(player: Node3D) -> void:
	signpost_activated.emit(message, self)
	U_ECSEventBus.publish(SIGNPOST_MESSAGE_EVENT, {
		"message": message,
		"controller_id": get_instance_id(),
		"repeatable": repeatable
	})
	if not repeatable:
		lock()
		_hide_interact_prompt()
	super._on_activated(player)
