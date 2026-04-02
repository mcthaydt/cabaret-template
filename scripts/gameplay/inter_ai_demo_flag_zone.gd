extends Area3D
class_name Inter_AIDemoFlagZone

const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")

const PLAYER_TAG_COMPONENT := StringName("C_PlayerTagComponent")
const SIGNPOST_MESSAGE_EVENT := StringName("signpost_message")

@export var ai_flag_id: StringName = StringName("")
@export var ai_flag_value: bool = true
@export var completed_area_id: String = ""
@export var signpost_message: String = ""
@export var signpost_duration_sec: float = 1.5
@export var trigger_once: bool = true

var _has_triggered: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not _is_player_body(body):
		return
	if trigger_once and _has_triggered:
		return

	_has_triggered = true
	_dispatch_gameplay_updates()
	_publish_signpost_message()

func _dispatch_gameplay_updates() -> void:
	var store: I_StateStore = U_STATE_UTILS.try_get_store(self)
	if store == null:
		return

	if ai_flag_id != StringName(""):
		store.dispatch(U_GAMEPLAY_ACTIONS.set_ai_demo_flag(ai_flag_id, ai_flag_value))

	if not completed_area_id.is_empty():
		store.dispatch(U_GAMEPLAY_ACTIONS.mark_area_complete(completed_area_id))

func _publish_signpost_message() -> void:
	if signpost_message.is_empty():
		return
	U_ECSEventBus.publish(SIGNPOST_MESSAGE_EVENT, {
		"message": signpost_message,
		"message_duration_sec": maxf(signpost_duration_sec, 0.1),
	})

func _is_player_body(body: Node3D) -> bool:
	if body == null:
		return false

	var entity: Node = U_ECS_UTILS.find_entity_root(body)
	if entity == null:
		return false

	var manager: I_ECSManager = U_ECS_UTILS.get_manager(self) as I_ECSManager
	if manager == null:
		return false

	var components: Dictionary = manager.get_components_for_entity(entity)
	return components.has(PLAYER_TAG_COMPONENT) and components.get(PLAYER_TAG_COMPONENT) != null
