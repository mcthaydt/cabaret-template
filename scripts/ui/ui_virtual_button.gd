extends Control
class_name UI_VirtualButton

const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")

signal button_pressed(action: StringName)
signal button_released(action: StringName)

enum ActionType {
	TAP,
	HOLD
}

@export var action: StringName = StringName("jump")
@export var action_type: ActionType = ActionType.HOLD
@export var can_reposition: bool = false
@export var control_name: StringName = StringName()
@export var button_texture: Texture2D

const DEFAULT_SIZE := Vector2(100, 100)
const DEFAULT_TEXTURE_PATH := "res://resources/button_prompts/mobile/button_background.png"
const PRESSED_SCALE := Vector2(0.95, 0.95)
const RELEASED_SCALE := Vector2.ONE
const PRESSED_MODULATE := Color(0.8, 0.8, 0.8, 1.0)
const RELEASED_MODULATE := Color(1, 1, 1, 1)
const ACTION_COLORS := {
	StringName("jump"): Color(0.6, 0.9, 1.0),
	StringName("sprint"): Color(0.6, 1.0, 0.7),
	StringName("interact"): Color(1.0, 0.85, 0.6),
	StringName("pause"): Color(1.0, 0.6, 0.7)
}

const BRIDGE_MODE_NONE := 0
const BRIDGE_MODE_INPUT_ACTION := 1
const BRIDGE_MODE_PAUSE_TOGGLE := 2

const ACTION_BRIDGE_MODES := {
	StringName("interact"): BRIDGE_MODE_INPUT_ACTION,
	StringName("pause"): BRIDGE_MODE_PAUSE_TOGGLE,
}

@onready var _button_texture_rect: TextureRect = null
@onready var _action_label: Label = null

var _touch_id: int = -1
var _is_pressed: bool = false
var _is_repositioning: bool = false
var _touch_offset_from_control: Vector2 = Vector2.ZERO
var _store: I_StateStore = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	_button_texture_rect = get_node_or_null("ButtonTexture") as TextureRect
	_action_label = get_node_or_null("ActionLabel") as Label
	_ensure_default_size()
	_apply_button_texture()
	_refresh_label()
	_apply_release_visuals()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_handle_touch_press(touch)
		else:
			_handle_touch_release(touch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)

func is_pressed() -> bool:
	return _is_pressed

func _handle_touch_press(event: InputEventScreenTouch) -> void:
	if _touch_id != -1:
		return
	if not _is_touch_inside(event.position):
		return
	_touch_id = event.index
	_is_repositioning = can_reposition
	if _is_repositioning:
		_touch_offset_from_control = _get_parent_local_position(event.position) - position
		_is_pressed = false
		return
	_press()

func _handle_touch_release(event: InputEventScreenTouch) -> void:
	if event.index != _touch_id:
		return
	_release()

func _handle_drag(event: InputEventScreenDrag) -> void:
	if _touch_id == -1 or event.index != _touch_id:
		return
	if _is_repositioning:
		var parent_local := _get_parent_local_position(event.position)
		position = parent_local - _touch_offset_from_control
		return
	if not _is_touch_inside(event.position):
		_release(true)

func _press() -> void:
	_is_pressed = true
	_apply_pressed_visuals()
	_bridge_on_press()
	if action_type == ActionType.HOLD:
		button_pressed.emit(action)

func _release(was_canceled: bool = false) -> void:
	var was_pressed := _is_pressed
	var was_repositioning := _is_repositioning
	_touch_id = -1
	_is_pressed = false
	_is_repositioning = false
	_touch_offset_from_control = Vector2.ZERO
	if was_pressed and action_type == ActionType.TAP and not was_canceled:
		button_pressed.emit(action)
	if was_pressed:
		button_released.emit(action)
		_bridge_on_release(was_repositioning)
	_apply_release_visuals()
	if was_repositioning:
		_save_position()

func _ensure_default_size() -> void:
	if size.is_zero_approx():
		size = DEFAULT_SIZE
	custom_minimum_size = DEFAULT_SIZE

func _apply_button_texture() -> void:
	if _button_texture_rect == null:
		return
	if button_texture == null:
		button_texture = _load_texture(DEFAULT_TEXTURE_PATH)
	_button_texture_rect.texture = button_texture
	if button_texture != null:
		var tex_size := button_texture.get_size()
		_button_texture_rect.custom_minimum_size = tex_size
		_button_texture_rect.set_deferred("size", tex_size)
	_refresh_label()

func _refresh_label() -> void:
	if _action_label == null:
		return
	var label_text := String(action)
	if label_text.is_empty():
		label_text = "?"
	_action_label.text = label_text.capitalize()
	var tint: Color = ACTION_COLORS.get(action, Color(1, 1, 1, 0.9))
	_action_label.modulate = tint

func _apply_pressed_visuals() -> void:
	modulate = PRESSED_MODULATE
	scale = PRESSED_SCALE

func _apply_release_visuals() -> void:
	modulate = RELEASED_MODULATE
	scale = RELEASED_SCALE

func _is_touch_inside(touch_position: Vector2) -> bool:
	return get_global_rect().has_point(touch_position)

func _save_position() -> void:
	var key_name: StringName = control_name
	if key_name == StringName():
		key_name = action
	if key_name == StringName():
		return
	var store := _get_store_instance()
	if store == null:
		return
	var action_dict := U_InputActions.save_virtual_control_position(String(key_name), position)
	store.dispatch(action_dict)

func _bridge_on_press() -> void:
	var mode := int(ACTION_BRIDGE_MODES.get(action, BRIDGE_MODE_NONE))
	match mode:
		BRIDGE_MODE_INPUT_ACTION:
			_bridge_input_action_pressed(action)
		BRIDGE_MODE_PAUSE_TOGGLE:
			_bridge_pause_pressed()
		_:
			pass

func _bridge_on_release(was_repositioning: bool) -> void:
	if was_repositioning:
		return
	var mode := int(ACTION_BRIDGE_MODES.get(action, BRIDGE_MODE_NONE))
	match mode:
		BRIDGE_MODE_INPUT_ACTION:
			_bridge_input_action_released(action)
		_:
			pass

func _bridge_input_action_pressed(action_name: StringName) -> void:
	if action_name == StringName():
		return
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	Input.action_press(action_name)

func _bridge_input_action_released(action_name: StringName) -> void:
	if action_name == StringName():
		return
	if not InputMap.has_action(action_name):
		return
	Input.action_release(action_name)

func _bridge_pause_pressed() -> void:
	var store := _get_store_instance()
	if store == null:
		return

	var nav_slice := store.get_slice(StringName("navigation"))

	if U_NavigationSelectors.is_paused(nav_slice):
		store.dispatch(U_NavigationActions.close_pause())
	else:
		store.dispatch(U_NavigationActions.open_pause())

func _get_parent_local_position(global_point: Vector2) -> Vector2:
	var parent_canvas := get_parent()
	if parent_canvas is CanvasItem:
		var canvas_item := parent_canvas as CanvasItem
		var inverse := canvas_item.get_global_transform_with_canvas().affine_inverse()
		return inverse * global_point
	return global_point

func _load_texture(path: String) -> Texture2D:
	var resource := ResourceLoader.load(path)
	if resource is Texture2D:
		return resource
	return null

func _get_store_instance() -> I_StateStore:
	if _store != null and is_instance_valid(_store):
		return _store
	_store = U_StateUtils.try_get_store(self)
	return _store
