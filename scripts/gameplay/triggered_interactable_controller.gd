extends "res://scripts/gameplay/base_interactable_controller.gd"
class_name TriggeredInteractableController


enum TriggerMode {
	AUTO = 0,
	INTERACT = 1,
}

const PROMPT_SHOW_EVENT := StringName("interact_prompt_show")
const PROMPT_HIDE_EVENT := StringName("interact_prompt_hide")
const INTERACTION_HINT_NODE_NAME := "SO_InteractionHintIcon"
const INTERACTION_HINT_DEFAULT_OFFSET := Vector3.ZERO
const INTERACTION_HINT_MIN_SCALE := 0.1
const INTERACTION_HINT_BILLBOARD_MODE := BaseMaterial3D.BILLBOARD_ENABLED

var _trigger_mode: TriggerMode = TriggerMode.AUTO
@export var trigger_mode: TriggerMode:
	get:
		return _trigger_mode
	set(value):
		if _trigger_mode == value:
			return
		_trigger_mode = value
		if _trigger_mode != TriggerMode.INTERACT:
			_hide_interact_prompt()
		_refresh_interaction_hint_visibility()

@export var interact_action: StringName = StringName("interact")
@export var interact_prompt: String = "Interact"

var _interaction_hint_enabled: bool = false
@export var interaction_hint_enabled: bool:
	get:
		return _interaction_hint_enabled
	set(value):
		if _interaction_hint_enabled == value:
			return
		_interaction_hint_enabled = value
		_refresh_interaction_hint_visibility()

var _interaction_hint_icon: Texture2D = null
@export var interaction_hint_icon: Texture2D:
	get:
		return _interaction_hint_icon
	set(value):
		if _interaction_hint_icon == value:
			return
		_interaction_hint_icon = value
		_apply_interaction_hint_transform()
		_refresh_interaction_hint_visibility()

var _interaction_hint_offset: Vector3 = INTERACTION_HINT_DEFAULT_OFFSET
@export var interaction_hint_offset: Vector3:
	get:
		return _interaction_hint_offset
	set(value):
		if _interaction_hint_offset.is_equal_approx(value):
			return
		_interaction_hint_offset = value
		_apply_interaction_hint_transform()

var _interaction_hint_scale: float = 1.0
@export_range(0.1, 4.0, 0.05, "or_greater") var interaction_hint_scale: float:
	get:
		return _interaction_hint_scale
	set(value):
		var clamped := maxf(value, INTERACTION_HINT_MIN_SCALE)
		if is_equal_approx(_interaction_hint_scale, clamped):
			return
		_interaction_hint_scale = clamped
		_apply_interaction_hint_transform()

var _active_prompt_shown: bool = false
var _active_prompt_controller_id: int = 0
var _interaction_hint_icon_sprite: Sprite3D = null

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_refresh_interaction_hint_visibility()
	if _trigger_mode != TriggerMode.INTERACT:
		return
	if interact_action.is_empty():
		return
	if not is_player_in_zone():
		return
	# Block interact input during toast display + cooldown
	if U_InteractBlocker.is_blocked():
		return
	var action_name := String(interact_action)
	if not InputMap.has_action(action_name):
		return
	if not Input.is_action_just_pressed(action_name):
		return
	var player := get_primary_player()
	if player == null:
		return
	activate(player)

func _on_player_entered(player: Node3D) -> void:
	if _trigger_mode == TriggerMode.AUTO:
		activate(player)
	else:
		_show_interact_prompt()
	_refresh_interaction_hint_visibility()
	super._on_player_entered(player)

func _on_player_exited(player: Node3D) -> void:
	_hide_interact_prompt()
	_refresh_interaction_hint_visibility()
	super._on_player_exited(player)

func _on_enabled_state_changed(enabled: bool) -> void:
	super._on_enabled_state_changed(enabled)
	if not enabled:
		_hide_interact_prompt()
	_refresh_interaction_hint_visibility()

func _exit_tree() -> void:
	_hide_interact_prompt()
	_hide_interaction_hint()
	_interaction_hint_icon_sprite = null
	super._exit_tree()

func _show_interact_prompt() -> void:
	if _trigger_mode != TriggerMode.INTERACT:
		return
	if _active_prompt_shown:
		return
	if interact_action.is_empty():
		return
	# Do not show prompts while transitions/overlays are active (pause/menus)
	if _is_transition_blocked():
		return
	# Suppress prompt publication while interactions are actively blocked by HUD feedback.
	if U_InteractBlocker.is_blocked():
		return

	var payload := {
		"controller_id": get_instance_id(),
		"action": interact_action,
		"prompt": interact_prompt
	}
	U_ECSEventBus.publish(PROMPT_SHOW_EVENT, payload)
	_active_prompt_shown = true
	_active_prompt_controller_id = get_instance_id()

func _hide_interact_prompt() -> void:
	if not _active_prompt_shown:
		return
	var payload := {
		"controller_id": _active_prompt_controller_id
	}
	U_ECSEventBus.publish(PROMPT_HIDE_EVENT, payload)
	_active_prompt_shown = false
	_active_prompt_controller_id = 0

func _should_show_interaction_hint() -> bool:
	if _trigger_mode != TriggerMode.INTERACT:
		return false
	if not interaction_hint_enabled:
		return false
	if interaction_hint_icon == null:
		return false
	if interact_action.is_empty():
		return false
	if not is_enabled():
		return false
	if _is_transition_blocked():
		return false
	if U_InteractBlocker.is_blocked():
		return false
	return true

func _refresh_interaction_hint_visibility() -> void:
	if not interaction_hint_enabled or interaction_hint_icon == null:
		_hide_interaction_hint()
		return

	var sprite := _ensure_interaction_hint_sprite()
	if sprite == null:
		return
	_apply_interaction_hint_transform()
	sprite.visible = _should_show_interaction_hint()

func _hide_interaction_hint() -> void:
	var sprite := _ensure_interaction_hint_sprite_reference()
	if sprite == null:
		return
	sprite.visible = false

func _ensure_interaction_hint_sprite_reference() -> Sprite3D:
	if _interaction_hint_icon_sprite != null and is_instance_valid(_interaction_hint_icon_sprite):
		_apply_interaction_hint_render_defaults(_interaction_hint_icon_sprite)
		return _interaction_hint_icon_sprite
	var existing := get_node_or_null(INTERACTION_HINT_NODE_NAME) as Sprite3D
	if existing != null:
		_apply_interaction_hint_render_defaults(existing)
		_interaction_hint_icon_sprite = existing
	return _interaction_hint_icon_sprite

func _ensure_interaction_hint_sprite() -> Sprite3D:
	var existing := _ensure_interaction_hint_sprite_reference()
	if existing != null:
		return existing

	var sprite := Sprite3D.new()
	sprite.name = INTERACTION_HINT_NODE_NAME
	sprite.visible = false
	add_child(sprite)
	_apply_interaction_hint_render_defaults(sprite)
	_interaction_hint_icon_sprite = sprite
	return sprite

func _apply_interaction_hint_transform() -> void:
	var sprite := _ensure_interaction_hint_sprite_reference()
	if sprite == null:
		return
	sprite.texture = interaction_hint_icon
	sprite.position = interaction_hint_offset
	var uniform_scale := maxf(interaction_hint_scale, INTERACTION_HINT_MIN_SCALE)
	sprite.scale = Vector3(uniform_scale, uniform_scale, uniform_scale)

func _apply_interaction_hint_render_defaults(sprite: Sprite3D) -> void:
	if sprite == null:
		return
	sprite.billboard = INTERACTION_HINT_BILLBOARD_MODE
	sprite.double_sided = true
	sprite.shaded = false

func _apply_interaction_hint_config(config: Resource) -> void:
	if config == null:
		return

	var enabled: bool = false
	var enabled_variant: Variant = config.get("interaction_hint_enabled")
	if enabled_variant is bool:
		enabled = enabled_variant

	var icon: Texture2D = null
	var icon_variant: Variant = config.get("interaction_hint_icon")
	if icon_variant is Texture2D:
		icon = icon_variant as Texture2D

	var offset := INTERACTION_HINT_DEFAULT_OFFSET
	var offset_variant: Variant = config.get("interaction_hint_offset")
	if offset_variant is Vector3:
		offset = offset_variant as Vector3

	var scale: float = 1.0
	var scale_variant: Variant = config.get("interaction_hint_scale")
	if scale_variant is float:
		scale = scale_variant
	elif scale_variant is int:
		scale = float(scale_variant)

	interaction_hint_enabled = enabled
	interaction_hint_icon = icon
	interaction_hint_offset = offset
	interaction_hint_scale = maxf(scale, INTERACTION_HINT_MIN_SCALE)
