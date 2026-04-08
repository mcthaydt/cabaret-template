extends Area3D
class_name Inter_AIDemoFlagZone

const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")

const PLAYER_TAG_COMPONENT := StringName("C_PlayerTagComponent")
const SIGNPOST_MESSAGE_EVENT := StringName("signpost_message")
const PROMPT_SHOW_EVENT := StringName("interact_prompt_show")
const PROMPT_HIDE_EVENT := StringName("interact_prompt_hide")
const INTERACTION_HINT_NODE_NAME := "SO_InteractionHintIcon"
const INTERACTION_HINT_VISUAL_SCALE := 0.35

@export var ai_flag_id: StringName = StringName("")
@export var ai_flag_value: bool = true
@export var completed_area_id: String = ""
@export var signpost_message: String = ""
@export var signpost_duration_sec: float = 1.5
@export var action_required: bool = false
@export var interact_action: StringName = StringName("interact")
@export var interact_prompt: String = "hud.interact_read"
@export var interaction_hint_icon: Texture2D = null
@export var interaction_hint_offset: Vector3 = Vector3.ZERO
@export_range(0.1, 4.0, 0.05, "or_greater") var interaction_hint_scale: float = 1.0

var _has_dispatched: bool = false
var _player_in_zone: Node3D = null
var _prompt_shown: bool = false
var _hint_sprite: Sprite3D = null

func _ready() -> void:
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	_refresh_hint_visibility()
	if _player_in_zone == null:
		return
	if not _is_interact_mode():
		return
	if interact_action.is_empty():
		return
	var action_name := String(interact_action)
	if not InputMap.has_action(action_name):
		return
	if not Input.is_action_just_pressed(action_name):
		return
	if U_InteractBlocker.is_blocked():
		return
	_activate(_player_in_zone)

func _on_body_entered(body: Node3D) -> void:
	if not _is_player_body(body):
		return
	_player_in_zone = body

	if not _is_interact_mode():
		_activate(body)
	else:
		_show_interact_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body != _player_in_zone:
		return
	_hide_interact_prompt()
	_player_in_zone = null

func _activate(_player: Node3D) -> void:
	if not _has_dispatched:
		_has_dispatched = true
		_dispatch_gameplay_updates()
	_publish_signpost_message()

	if not action_required and _has_dispatched:
		_show_interact_prompt()

func _is_interact_mode() -> bool:
	if action_required:
		return true
	return _has_dispatched

func _dispatch_gameplay_updates() -> void:
	var store: I_StateStore = U_STATE_UTILS.try_get_store(self)
	if store == null:
		print("AIDemoFlagZone[%s]: ERROR - no state store found!" % ai_flag_id)
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

# --- Interact prompt ---

func _show_interact_prompt() -> void:
	if _prompt_shown:
		return
	if interact_action.is_empty():
		return
	if U_InteractBlocker.is_blocked():
		return
	U_ECSEventBus.publish(PROMPT_SHOW_EVENT, {
		"controller_id": get_instance_id(),
		"action": interact_action,
		"prompt": interact_prompt,
	})
	_prompt_shown = true

func _hide_interact_prompt() -> void:
	if not _prompt_shown:
		return
	U_ECSEventBus.publish(PROMPT_HIDE_EVENT, {
		"controller_id": get_instance_id(),
	})
	_prompt_shown = false

# --- Interaction hint icon ---

func _refresh_hint_visibility() -> void:
	if interaction_hint_icon == null:
		_hide_hint()
		return
	var sprite := _ensure_hint_sprite()
	if sprite == null:
		return
	sprite.texture = interaction_hint_icon
	sprite.position = interaction_hint_offset
	var s := maxf(interaction_hint_scale, 0.1) * INTERACTION_HINT_VISUAL_SCALE
	sprite.scale = Vector3(s, s, s)
	var mat := sprite.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_texture = interaction_hint_icon
	sprite.visible = _should_show_hint()

func _should_show_hint() -> bool:
	if interaction_hint_icon == null:
		return false
	if not _is_interact_mode():
		return false
	if interact_action.is_empty():
		return false
	if U_InteractBlocker.is_blocked():
		return false
	return true

func _hide_hint() -> void:
	if _hint_sprite != null and is_instance_valid(_hint_sprite):
		_hint_sprite.visible = false

func _ensure_hint_sprite() -> Sprite3D:
	if _hint_sprite != null and is_instance_valid(_hint_sprite):
		return _hint_sprite
	var existing := get_node_or_null(INTERACTION_HINT_NODE_NAME) as Sprite3D
	if existing != null:
		_hint_sprite = existing
		return _hint_sprite
	var sprite := Sprite3D.new()
	sprite.name = INTERACTION_HINT_NODE_NAME
	sprite.visible = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.render_priority = 1
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sprite.material_override = mat
	add_child(sprite)
	_hint_sprite = sprite
	return sprite

func _exit_tree() -> void:
	_hide_interact_prompt()
	_hint_sprite = null
