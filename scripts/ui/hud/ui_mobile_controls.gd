extends CanvasLayer
class_name UI_MobileControls

const VIRTUAL_JOYSTICK_SCENE := preload("res://scenes/ui/widgets/ui_virtual_joystick.tscn")
const VIRTUAL_BUTTON_SCENE := preload("res://scenes/ui/widgets/ui_virtual_button.tscn")

@export var force_enable: bool = false
@export var emulate_mobile_override: bool = false
@export var fade_delay: float = 2.0
@export var fade_duration: float = 0.5
@export_range(0.0, 1.0, 0.05) var idle_opacity: float = 0.3
@export_range(0.0, 1.0, 0.05) var active_opacity: float = 1.0

const DEFAULT_TOUCHSCREEN_PROFILE_PATH := "res://resources/input/profiles/cfg_default_touchscreen.tres"
const SHELL_GAMEPLAY := StringName("gameplay")
const EDIT_OVERLAY_ID := StringName("edit_touch_controls")

var _state_store: I_StateStore = null
var _unsubscribe: Callable = Callable()
var _controls_root: Control = null
var _default_touchscreen_settings: RS_TouchscreenSettings = RS_TouchscreenSettings.new()
var _joystick: UI_VirtualJoystick = null
var _buttons: Array[UI_VirtualButton] = []
var _profile: RS_InputProfile = null
var _profile_button_positions: Dictionary = {}
var _profile_joystick_position: Vector2 = Vector2.ZERO
var _device_type: int = M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE
var _is_transitioning: bool = false
var _has_overlay_active: bool = false
var _is_edit_overlay_active: bool = false
var _current_shell: StringName = StringName("")
var _current_scene_id: StringName = StringName("")
var _fade_delay: float = 0.0
var _fade_duration: float = 0.0
var _fade_elapsed: float = 0.0
var _is_fading: bool = false
var _overlay_input_logged: bool = false
var _awaiting_transition_signal: bool = false  # True when waiting for transition_visual_complete

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	visible = false

	if not _should_enable():
		queue_free()
		return

	_controls_root = get_node_or_null("Controls") as Control
	if _controls_root == null:
		_controls_root = Control.new()
		_controls_root.name = "Controls"
		add_child(_controls_root)

	_register_with_input_device_manager()

	_profile = _load_touchscreen_profile()
	_cache_profile_positions()

	_state_store = await U_StateUtils.await_store_ready(self)
	if _state_store == null:
		push_error("MobileControls: No M_StateStore available")
		return

	if _unsubscribe == Callable() or not _unsubscribe.is_valid():
		_unsubscribe = _state_store.subscribe(_on_state_changed)

	var initial_state := _state_store.get_state()
	_device_type = _normalize_device_type(U_InputSelectors.get_active_device_type(initial_state))

	_build_controls(initial_state)
	_apply_state(initial_state)
	_update_visibility()

	# Connect to SceneManager's transition_visual_complete signal
	# This tells us when fade-in animation completes and scene is fully visible
	var scene_manager := U_ServiceLocator.try_get_service(StringName("scene_manager"))
	if scene_manager != null and scene_manager.has_signal("transition_visual_complete"):
		scene_manager.transition_visual_complete.connect(_on_transition_visual_complete)

func _exit_tree() -> void:
	if _unsubscribe != Callable() and _unsubscribe.is_valid():
		_unsubscribe.call()
		_unsubscribe = Callable()
	_state_store = null
	_is_fading = false
	_fade_elapsed = 0.0
	_unregister_from_input_device_manager()

func _should_enable() -> bool:
	if force_enable:
		return true
	if OS.has_feature("mobile"):
		return true
	return _is_emulate_mode()

func _register_with_input_device_manager() -> void:
	var input_manager := U_ServiceLocator.try_get_service(StringName("input_device_manager")) as M_InputDeviceManager
	if input_manager != null:
		input_manager.register_mobile_controls(self)

func _unregister_from_input_device_manager() -> void:
	var input_manager := U_ServiceLocator.try_get_service(StringName("input_device_manager")) as M_InputDeviceManager
	if input_manager != null:
		input_manager.unregister_mobile_controls(self)

func _is_emulate_mode() -> bool:
	if emulate_mobile_override:
		return true
	var args: PackedStringArray = OS.get_cmdline_args()
	return args.has("--emulate-mobile")

func _load_touchscreen_profile() -> RS_InputProfile:
	var resource := ResourceLoader.load(DEFAULT_TOUCHSCREEN_PROFILE_PATH)
	if resource is RS_InputProfile:
		return resource as RS_InputProfile
	push_error("MobileControls: Failed to load default touchscreen profile")
	return null

func _cache_profile_positions() -> void:
	_profile_button_positions.clear()
	_profile_joystick_position = Vector2.ZERO

	if _profile != null:
		_profile_joystick_position = _profile.virtual_joystick_position
		for button_dict in _profile.virtual_buttons:
			var action_variant: Variant = button_dict.get("action")
			var position_variant: Variant = button_dict.get("position")
			if position_variant is Vector2:
				var action_name := StringName()
				if action_variant is StringName:
					action_name = action_variant
				elif action_variant is String:
					action_name = StringName(action_variant)
				if action_name != StringName():
					_profile_button_positions[String(action_name)] = position_variant

func _build_controls(state: Dictionary) -> void:
	_buttons.clear()
	if _joystick != null and is_instance_valid(_joystick):
		_joystick.queue_free()
		_joystick = null

	var joystick_instance := VIRTUAL_JOYSTICK_SCENE.instantiate() as UI_VirtualJoystick
	if joystick_instance != null:
		joystick_instance.name = "VirtualJoystick"
		_controls_root.add_child(joystick_instance)
		_joystick = joystick_instance
		_connect_input_signals(_joystick)

	for button_key in _profile_button_positions.keys():
		var button_instance := VIRTUAL_BUTTON_SCENE.instantiate() as UI_VirtualButton
		if button_instance == null:
			continue
		var action_name := StringName(button_key)
		button_instance.name = "Button_%s" % action_name
		button_instance.action = action_name
		_controls_root.add_child(button_instance)
		_buttons.append(button_instance)
		_connect_input_signals(button_instance)
	_apply_state(state)

func _apply_state(state: Dictionary) -> void:
	if state == null:
		return
	_device_type = _normalize_device_type(U_InputSelectors.get_active_device_type(state))

	_apply_touchscreen_settings(U_InputSelectors.get_touchscreen_settings(state))
	_apply_positions(state)
	_update_navigation_state(state)
	_clamp_all_controls()
	_update_visibility()

func _normalize_device_type(device_type: int) -> int:
	if device_type == M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE and _should_enable():
		return M_InputDeviceManager.DeviceType.TOUCHSCREEN
	return device_type

func _apply_touchscreen_settings(settings: Dictionary) -> void:
	if _joystick != null:
		var joystick_scale: float = float(settings.get("virtual_joystick_size", 1.0))
		_joystick.scale = Vector2.ONE * max(joystick_scale, 0.01)
		var joystick_alpha: float = float(settings.get("virtual_joystick_opacity", 0.7))
		_joystick.modulate.a = clampf(joystick_alpha, 0.0, 1.0)
		_joystick.deadzone = float(settings.get("joystick_deadzone", _default_touchscreen_settings.joystick_deadzone))

	var button_scale: float = float(settings.get("button_size", 1.0))
	var button_alpha: float = float(settings.get("button_opacity", 0.8))
	var custom_sizes: Dictionary = {}
	var custom_opacities: Dictionary = {}
	if settings.has("custom_button_sizes") and settings["custom_button_sizes"] is Dictionary:
		custom_sizes = settings["custom_button_sizes"]
	if settings.has("custom_button_opacities") and settings["custom_button_opacities"] is Dictionary:
		custom_opacities = settings["custom_button_opacities"]

	for button in _buttons:
		if button == null:
			continue
		var action_key := String(button.action)
		var size_value := button_scale
		if custom_sizes.has(action_key):
			size_value = float(custom_sizes.get(action_key, button_scale))
		button.scale = Vector2.ONE * max(size_value, 0.01)

		var opacity_value := button_alpha
		if custom_opacities.has(action_key):
			opacity_value = float(custom_opacities.get(action_key, button_alpha))
		button.modulate.a = clampf(opacity_value, 0.0, 1.0)

func _apply_positions(state: Dictionary, allow_overlay_override: bool = false) -> void:
	# Skip position updates when edit overlay is active - let user drag freely
	if _is_edit_overlay_active and not allow_overlay_override:
		return

	if _joystick != null:
		_joystick.position = _get_joystick_position(state)

	var button_positions := _get_button_positions(state)
	for button in _buttons:
		if button == null:
			continue
		var action_key := String(button.action)
		if button_positions.has(action_key):
			button.position = button_positions[action_key]

func _clamp_all_controls() -> void:
	_clamp_control_to_viewport(_joystick)
	for button in _buttons:
		_clamp_control_to_viewport(button)

func _clamp_control_to_viewport(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	var scaled_size: Vector2 = control.size * control.scale
	var clamped_position := control.position
	clamped_position.x = clampf(clamped_position.x, 0.0, max(viewport_size.x - scaled_size.x, 0.0))
	clamped_position.y = clampf(clamped_position.y, 0.0, max(viewport_size.y - scaled_size.y, 0.0))
	control.position = clamped_position

func _get_joystick_position(state: Dictionary) -> Vector2:
	var custom: Variant = U_InputSelectors.get_virtual_control_position(state, "virtual_joystick")
	if custom is Vector2:
		return custom
	return _profile_joystick_position

func _get_button_positions(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var custom_positions_variant: Variant = U_InputSelectors.get_touchscreen_settings(state).get("custom_button_positions", {})
	var custom_positions: Dictionary = {}
	if custom_positions_variant is Dictionary:
		custom_positions = custom_positions_variant
	for action_key in _profile_button_positions.keys():
		var custom_position: Variant = custom_positions.get(action_key)
		if custom_position == null and custom_positions.has(StringName(action_key)):
			custom_position = custom_positions.get(StringName(action_key))
		if custom_position is Vector2:
			result[action_key] = custom_position
		else:
			result[action_key] = _profile_button_positions.get(action_key, Vector2.ZERO)
	return result

func _update_navigation_state(state: Dictionary) -> void:
	var nav_state: Dictionary = state.get("navigation", {})
	var previous_overlay_active: bool = _has_overlay_active

	_current_shell = U_NavigationSelectors.get_shell(nav_state)
	var stack: Array = U_NavigationSelectors.get_overlay_stack(nav_state)
	_has_overlay_active = stack.size() > 0
	_is_edit_overlay_active = U_NavigationSelectors.get_top_overlay_id(nav_state) == EDIT_OVERLAY_ID
	if previous_overlay_active != _has_overlay_active:
		_overlay_input_logged = false

	var scene_state: Dictionary = state.get("scene", {})
	var was_transitioning: bool = _is_transitioning
	_is_transitioning = bool(scene_state.get("is_transitioning", false))
	_current_scene_id = scene_state.get("current_scene_id", StringName(""))

	# When transition starts, block visibility updates until signal fires
	if not was_transitioning and _is_transitioning:
		_awaiting_transition_signal = true

	# Fallback: If state says transition ended but we're still waiting for signal, unblock
	# This handles test environments without real SceneManager or missed signals
	if was_transitioning and not _is_transitioning and _awaiting_transition_signal:
		_awaiting_transition_signal = false

func _update_visibility() -> void:
	# Always show controls when editing, regardless of device type
	if _is_edit_overlay_active:
		visible = true
		_awaiting_transition_signal = false
		return

	# Block all visibility updates if waiting for transition signal
	if _awaiting_transition_signal:
		visible = false
		return

	var device_allows: bool = _device_type == M_InputDeviceManager.DeviceType.TOUCHSCREEN
	var shell_allows: bool = (_current_shell == SHELL_GAMEPLAY) or (force_enable and _current_shell == StringName(""))
	var overlay_allows: bool = not _has_overlay_active or _is_edit_overlay_active
	var scene_allows: bool = true
	if not force_enable:
		scene_allows = U_SceneRegistry.get_scene_type(_current_scene_id) == U_SceneRegistry.SceneType.GAMEPLAY

	var should_show: bool = device_allows and shell_allows and scene_allows and not _is_transitioning and overlay_allows

	visible = should_show

func _on_state_changed(__action: Dictionary, state: Dictionary) -> void:
	if state == null:
		return
	_apply_state(state)

## Called when SceneManager's visual transition completes (fade-in finishes)
func _on_transition_visual_complete(__scene_id: StringName) -> void:
	if _awaiting_transition_signal:
		_awaiting_transition_signal = false
		_update_visibility()

func force_apply_positions(state: Dictionary, clamp_controls: bool = true) -> void:
	_apply_positions(state, true)
	if clamp_controls:
		_clamp_all_controls()

func _connect_input_signals(control: Node) -> void:
	if control == null:
		return
	if control.has_signal("joystick_moved"):
		control.joystick_moved.connect(_on_input_activity)
	if control.has_signal("joystick_released"):
		control.joystick_released.connect(_on_input_activity)
	if control.has_signal("button_pressed"):
		control.button_pressed.connect(func(_action: StringName) -> void:
			_on_input_activity()
		)
	if control.has_signal("button_released"):
		control.button_released.connect(func(_action: StringName) -> void:
			_on_input_activity()
		)

## Called when the player interacts with any virtual control.
## Resets opacity to the active value and schedules a tween back to idle opacity.
func _on_input_activity(__data: Variant = null) -> void:
	if _controls_root == null:
		return
	if _has_overlay_active:
		return
	var active_color: Color = _controls_root.modulate
	active_color.a = active_opacity
	_controls_root.modulate = active_color
	_fade_delay = max(fade_delay, 0.0)
	_fade_duration = max(fade_duration, 0.0)
	_fade_elapsed = 0.0
	_is_fading = true

func _process(_delta: float) -> void:
	if _controls_root == null or not _is_fading:
		return
	var step: float = max(_delta, 1.0 / 60.0)
	_fade_elapsed += step
	if _fade_elapsed < _fade_delay:
		return
	var progress: float = 1.0
	if _fade_duration > 0.0:
		progress = clampf((_fade_elapsed - _fade_delay) / _fade_duration, 0.0, 1.0)
	var color: Color = _controls_root.modulate
	color.a = lerp(active_opacity, idle_opacity, progress)
	_controls_root.modulate = color
	if progress >= 1.0:
		_is_fading = false

func get_buttons() -> Array:
	return _buttons.duplicate()
