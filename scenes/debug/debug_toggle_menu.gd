extends Control
class_name SC_DebugToggleMenu

## Debug Toggle Menu (F4) - Phase 6
##
## Provides UI controls for all debug toggles:
## - Cheats tab: god_mode, infinite_jump, speed_modifier, time_scale
## - Visual tab: show_collision_shapes, show_spawn_points, show_trigger_zones, show_entity_labels
## - System tab: disable_gravity, disable_input
##
## Redux Integration:
## - Subscribes to debug slice updates to sync UI state
## - Dispatches U_DebugActions on checkbox/slider changes
## - Prevents infinite loops with _updating_from_state flag

const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_DebugActions := preload("res://scripts/state/actions/u_debug_actions.gd")
const U_DebugSelectors := preload("res://scripts/state/selectors/u_debug_selectors.gd")

# Node references (using unique names %)
@onready var close_button: Button = %CloseButton
@onready var god_mode_checkbox: CheckBox = %GodModeCheckBox
@onready var infinite_jump_checkbox: CheckBox = %InfiniteJumpCheckBox
@onready var speed_slider: HSlider = %SpeedSlider
@onready var speed_value_label: Label = %SpeedValueLabel
@onready var time_scale_slider: HSlider = %TimeScaleSlider
@onready var time_scale_value_label: Label = %TimeScaleValueLabel
@onready var show_collision_checkbox: CheckBox = %ShowCollisionCheckBox
@onready var show_spawn_points_checkbox: CheckBox = %ShowSpawnPointsCheckBox
@onready var show_triggers_checkbox: CheckBox = %ShowTriggersCheckBox
@onready var show_labels_checkbox: CheckBox = %ShowLabelsCheckBox
@onready var disable_gravity_checkbox: CheckBox = %DisableGravityCheckBox
@onready var disable_input_checkbox: CheckBox = %DisableInputCheckBox

var _store: I_StateStore = null
var _store_unsubscribe: Callable = Callable()
var _updating_from_state := false  # Prevent infinite loops during state sync


func _ready() -> void:
	# Get state store
	_store = U_StateUtils.get_store(self)

	# Subscribe to debug slice updates
	if _store:
		_store_unsubscribe = _store.subscribe(_on_state_changed)

	# Connect UI signals
	close_button.pressed.connect(_on_close_pressed)
	god_mode_checkbox.toggled.connect(_on_god_mode_toggled)
	infinite_jump_checkbox.toggled.connect(_on_infinite_jump_toggled)
	speed_slider.value_changed.connect(_on_speed_changed)
	time_scale_slider.value_changed.connect(_on_time_scale_changed)
	show_collision_checkbox.toggled.connect(_on_show_collision_toggled)
	show_spawn_points_checkbox.toggled.connect(_on_show_spawn_points_toggled)
	show_triggers_checkbox.toggled.connect(_on_show_triggers_toggled)
	show_labels_checkbox.toggled.connect(_on_show_labels_toggled)
	disable_gravity_checkbox.toggled.connect(_on_disable_gravity_toggled)
	disable_input_checkbox.toggled.connect(_on_disable_input_toggled)

	# Initial sync from state
	_sync_from_state()


func _exit_tree() -> void:
	if _store_unsubscribe.is_valid():
		_store_unsubscribe.call()


func _on_state_changed(_action: Dictionary, _state: Dictionary) -> void:
	_sync_from_state()


func _sync_from_state() -> void:
	if not _store:
		return

	_updating_from_state = true
	var state := _store.get_state()

	# Sync checkboxes from Redux state
	god_mode_checkbox.button_pressed = U_DebugSelectors.is_god_mode(state)
	infinite_jump_checkbox.button_pressed = U_DebugSelectors.is_infinite_jump(state)
	show_collision_checkbox.button_pressed = U_DebugSelectors.is_showing_collision_shapes(state)
	show_spawn_points_checkbox.button_pressed = U_DebugSelectors.is_showing_spawn_points(state)
	show_triggers_checkbox.button_pressed = U_DebugSelectors.is_showing_trigger_zones(state)
	show_labels_checkbox.button_pressed = U_DebugSelectors.is_showing_entity_labels(state)
	disable_gravity_checkbox.button_pressed = U_DebugSelectors.is_gravity_disabled(state)
	disable_input_checkbox.button_pressed = U_DebugSelectors.is_input_disabled(state)

	# Sync sliders from Redux state
	var speed_mod := U_DebugSelectors.get_speed_modifier(state)
	speed_slider.value = speed_mod
	speed_value_label.text = "%.2fx" % speed_mod

	var time_scale := U_DebugSelectors.get_time_scale(state)
	time_scale_slider.value = time_scale
	time_scale_value_label.text = "%.2fx" % time_scale

	_updating_from_state = false


## UI Signal Handlers (dispatch Redux actions)


func _on_close_pressed() -> void:
	visible = false


func _on_god_mode_toggled(pressed: bool) -> void:
	if _updating_from_state or not _store:
		return
	_store.dispatch(U_DebugActions.set_god_mode(pressed))


func _on_infinite_jump_toggled(pressed: bool) -> void:
	if _updating_from_state or not _store:
		return
	_store.dispatch(U_DebugActions.set_infinite_jump(pressed))


func _on_speed_changed(value: float) -> void:
	if _updating_from_state or not _store:
		return
	speed_value_label.text = "%.2fx" % value
	_store.dispatch(U_DebugActions.set_speed_modifier(value))


func _on_time_scale_changed(value: float) -> void:
	if _updating_from_state or not _store:
		return
	time_scale_value_label.text = "%.2fx" % value
	_store.dispatch(U_DebugActions.set_time_scale(value))


func _on_show_collision_toggled(pressed: bool) -> void:
	if _updating_from_state or not _store:
		return
	_store.dispatch(U_DebugActions.set_show_collision_shapes(pressed))


func _on_show_spawn_points_toggled(pressed: bool) -> void:
	if _updating_from_state or not _store:
		return
	_store.dispatch(U_DebugActions.set_show_spawn_points(pressed))


func _on_show_triggers_toggled(pressed: bool) -> void:
	if _updating_from_state or not _store:
		return
	_store.dispatch(U_DebugActions.set_show_trigger_zones(pressed))


func _on_show_labels_toggled(pressed: bool) -> void:
	if _updating_from_state or not _store:
		return
	_store.dispatch(U_DebugActions.set_show_entity_labels(pressed))


func _on_disable_gravity_toggled(pressed: bool) -> void:
	if _updating_from_state or not _store:
		return
	_store.dispatch(U_DebugActions.set_disable_gravity(pressed))


func _on_disable_input_toggled(pressed: bool) -> void:
	if _updating_from_state or not _store:
		return
	_store.dispatch(U_DebugActions.set_disable_input(pressed))
