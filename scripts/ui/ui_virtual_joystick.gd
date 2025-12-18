extends Control
class_name UI_VirtualJoystick

const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const RS_TouchscreenSettings := preload("res://scripts/ecs/resources/rs_touchscreen_settings.gd")

signal joystick_moved(vector: Vector2)
signal joystick_released

@export var joystick_radius: float = 120.0
@export_range(0.0, 1.0, 0.01) var deadzone: float = 0.15
@export var can_reposition: bool = false
@export var control_name: StringName = StringName("virtual_joystick")
@export var base_texture: Texture2D
@export var thumb_texture: Texture2D

const DEFAULT_BASE_TEXTURE_PATH := "res://resources/button_prompts/mobile/joystick_base.png"
const DEFAULT_THUMB_TEXTURE_PATH := "res://resources/button_prompts/mobile/joystick_thumb.png"

@onready var _base_texture_rect: TextureRect = %BaseTexture
@onready var _thumb_texture_rect: TextureRect = %ThumbTexture

var _touch_id: int = -1
var _touch_start_position: Vector2 = Vector2.ZERO
var _current_vector: Vector2 = Vector2.ZERO
var _is_active: bool = false
var _is_repositioning: bool = false
var _touch_offset_from_control: Vector2 = Vector2.ZERO
var _store: I_StateStore = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_apply_default_size()
	_apply_textures()
	_reset_thumb()

func is_active() -> bool:
	return _is_active

func get_vector() -> Vector2:
	return _current_vector

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)

func _handle_touch(event: InputEventScreenTouch) -> void:
	var touch_position: Vector2 = _normalize_touch_position(event.position)
	if event.pressed:
		if _touch_id != -1:
			return
		if not get_global_rect().has_point(touch_position):
			return
		_touch_id = event.index
		_is_active = true
		_is_repositioning = can_reposition
		_touch_start_position = touch_position
		_touch_offset_from_control = _get_parent_local_position(touch_position) - position
		if not _is_repositioning:
			_current_vector = Vector2.ZERO
			_reset_thumb()
	else:
		if event.index != _touch_id:
			return
		_release()

func _handle_drag(event: InputEventScreenDrag) -> void:
	if _touch_id == -1 or event.index != _touch_id:
		return

	var touch_position: Vector2 = _normalize_touch_position(event.position)
	if _is_repositioning:
		var parent_local := _get_parent_local_position(touch_position)
		position = parent_local - _touch_offset_from_control
		_current_vector = Vector2.ZERO
		return

	var offset := touch_position - _touch_start_position
	var clamped_offset := _clamp_offset(offset)
	_current_vector = _calculate_joystick_vector(clamped_offset)
	_update_thumb_position(clamped_offset)
	joystick_moved.emit(_current_vector)

func _clamp_offset(offset: Vector2) -> Vector2:
	var radius: float = max(joystick_radius, 1.0)
	if offset.length() <= radius:
		return offset
	return offset.normalized() * radius

func _calculate_joystick_vector(clamped_offset: Vector2) -> Vector2:
	var radius: float = max(joystick_radius, 1.0)
	var normalized: Vector2 = clamped_offset / radius
	return RS_TouchscreenSettings.apply_touch_deadzone(normalized, deadzone)

func _release() -> void:
	var was_active := _is_active
	var was_repositioning := _is_repositioning
	_touch_id = -1
	_is_active = false
	_is_repositioning = false
	_touch_start_position = Vector2.ZERO
	_current_vector = Vector2.ZERO
	_reset_thumb()
	if was_active:
		joystick_released.emit()
	if was_repositioning:
		_save_position()

func _reset_thumb() -> void:
	_update_thumb_position(Vector2.ZERO)

func _update_thumb_position(offset: Vector2) -> void:
	if _thumb_texture_rect == null:
		return
	var center := size * 0.5
	var thumb_size := _thumb_texture_rect.size
	var thumb_origin := center - (thumb_size * 0.5) + offset
	_thumb_texture_rect.position = thumb_origin

func _apply_textures() -> void:
	if _base_texture_rect != null:
		if base_texture == null:
			base_texture = _load_texture(DEFAULT_BASE_TEXTURE_PATH)
		_base_texture_rect.texture = base_texture
	if _thumb_texture_rect != null:
		if thumb_texture == null:
			thumb_texture = _load_texture(DEFAULT_THUMB_TEXTURE_PATH)
		_thumb_texture_rect.texture = thumb_texture
		if thumb_texture != null:
			var thumb_size := thumb_texture.get_size()
			_thumb_texture_rect.custom_minimum_size = thumb_size
			_thumb_texture_rect.size = thumb_size

func _load_texture(path: String) -> Texture2D:
	var resource := ResourceLoader.load(path)
	if resource is Texture2D:
		return resource
	return null

func _apply_default_size() -> void:
	var default_size: Vector2 = Vector2.ONE * (max(joystick_radius, 1.0) * 2.0)
	if size.is_zero_approx():
		size = default_size
	custom_minimum_size = default_size

func _save_position() -> void:
	if control_name == StringName():
		return
	if _store == null or not is_instance_valid(_store):
		_store = U_StateUtils.get_store(self)
	if _store == null:
		return
	var action := U_InputActions.save_virtual_control_position(String(control_name), position)
	_store.dispatch(action)

func _get_parent_local_position(global_point: Vector2) -> Vector2:
	var parent_canvas := get_parent()
	if parent_canvas is CanvasItem:
		var canvas_item := parent_canvas as CanvasItem
		var inverse := canvas_item.get_global_transform_with_canvas().affine_inverse()
		return inverse * global_point
	return global_point

func _normalize_touch_position(raw_position: Vector2) -> Vector2:
	var global_rect := get_global_rect()
	if global_rect.has_point(raw_position):
		return raw_position
	var local_rect := Rect2(Vector2.ZERO, global_rect.size)
	if local_rect.has_point(raw_position):
		return global_rect.position + raw_position
	return raw_position
