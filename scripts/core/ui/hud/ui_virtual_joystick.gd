extends Control
class_name UI_VirtualJoystick


signal joystick_moved(vector: Vector2)
signal joystick_released

@export var joystick_radius: float = 120.0
@export_range(0.0, 1.0, 0.01) var deadzone: float = 0.15
@export var can_reposition: bool = false
@export var control_name: StringName = StringName("virtual_joystick")

@onready var _godot_joystick: VirtualJoystick = $GodotVirtualJoystick
@onready var _base_style: StyleBoxFlat = _create_base_style()
@onready var _tip_style: StyleBoxFlat = _create_tip_style()

var _store: I_StateStore = null
var _current_vector: Vector2 = Vector2.ZERO
var _is_active: bool = false

const DEFAULT_BASE_COLOR := Color(0.2, 0.2, 0.2, 0.3)
const DEFAULT_TIP_COLOR := Color(0.4, 0.4, 0.4, 0.8)
const CORNER_RADIUS := 999.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_godot_joystick()
	_apply_styles()
	_connect_godot_signals()

func _setup_godot_joystick() -> void:
	if _godot_joystick == null:
		return

	_godot_joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	_godot_joystick.joystick_size = joystick_radius * 2.0
	_godot_joystick.deadzone_ratio = deadzone
	_godot_joystick.joystick_mode = VirtualJoystick.JOYSTICK_DYNAMIC if can_reposition else VirtualJoystick.JOYSTICK_FIXED
	_godot_joystick.visibility_mode = VirtualJoystick.VISIBILITY_ALWAYS

func _apply_styles() -> void:
	if _godot_joystick == null:
		return
	
	_godot_joystick.add_theme_stylebox_override("normal_joystick", _base_style)
	_godot_joystick.add_theme_stylebox_override("pressed_joystick", _base_style)
	_godot_joystick.add_theme_stylebox_override("normal_tip", _tip_style)
	_godot_joystick.add_theme_stylebox_override("pressed_tip", _tip_style)

func _connect_godot_signals() -> void:
	if _godot_joystick == null:
		return
	
	_godot_joystick.pressed.connect(_on_godot_pressed)
	_godot_joystick.released.connect(_on_godot_released)
	_godot_joystick.flicked.connect(_on_godot_flicked)

func is_active() -> bool:
	return _is_active

func get_vector() -> Vector2:
	if not _is_active:
		return Vector2.ZERO
	return _current_vector

func _on_godot_pressed() -> void:
	_is_active = true

func _on_godot_released(_input_vector: Vector2) -> void:
	_is_active = false
	_current_vector = Vector2.ZERO
	joystick_released.emit()
	if can_reposition:
		_save_position()

func _on_godot_flicked(input_vector: Vector2) -> void:
	joystick_moved.emit(input_vector)

func simulate_input(vector: Vector2) -> void:
	_is_active = vector != Vector2.ZERO
	_current_vector = vector
	joystick_moved.emit(vector)

func _save_position() -> void:
	if control_name == StringName():
		return
	if _store == null or not is_instance_valid(_store):
		_store = U_StateUtils.get_store(self)
	if _store == null:
		return
	var action := U_InputActions.save_virtual_control_position(String(control_name), position)
	_store.dispatch(action)

func _create_base_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DEFAULT_BASE_COLOR
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	return style

func _create_tip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DEFAULT_TIP_COLOR
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	return style

func _set_godot_joystick_property(name: String, value: Variant) -> void:
	if _godot_joystick == null:
		return
	_godot_joystick.set(name, value)

func _get_godot_joystick_property(name: String) -> Variant:
	if _godot_joystick == null:
		return null
	return _godot_joystick.get(name)

func _process(_delta: float) -> void:
	if not _is_active or _godot_joystick == null:
		return
	_current_vector = Input.get_vector(
		StringName("ui_left"), StringName("ui_right"),
		StringName("ui_up"), StringName("ui_down"),
		0.0
	)

func _gui_input(event: InputEvent) -> void:
	pass

func _input(event: InputEvent) -> void:
	pass
