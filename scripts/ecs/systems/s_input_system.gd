extends ECSSystem

class_name S_InputSystem

const INPUT_TYPE := StringName("C_InputComponent")

@export var negative_x_action: StringName = StringName("move_left")
@export var positive_x_action: StringName = StringName("move_right")
@export var negative_z_action: StringName = StringName("move_forward")
@export var positive_z_action: StringName = StringName("move_backward")
@export var jump_action: StringName = StringName("jump")
@export var sprint_action: StringName = StringName("sprint")
@export var input_deadzone: float = 0.15

var _actions_initialized := false

func on_configured() -> void:
    _ensure_actions()

func process_tick(_delta: float) -> void:
    _ensure_actions()

    var movement_vector := Input.get_vector(negative_x_action, positive_x_action, negative_z_action, positive_z_action)
    var mv_len := movement_vector.length()
    if mv_len > 0.0 and mv_len < input_deadzone:
        movement_vector = Vector2.ZERO
    var jump_pressed := Input.is_action_just_pressed(jump_action)
    var sprint_pressed := Input.is_action_pressed(sprint_action)

    for component in get_components(INPUT_TYPE):
        if component == null:
            continue

        var input_component: C_InputComponent = component as C_InputComponent
        if input_component == null:
            continue

        input_component.set_move_vector(movement_vector)
        input_component.set_sprint_pressed(sprint_pressed)
        if jump_pressed:
            input_component.set_jump_pressed(true)

func _ensure_actions() -> void:
    if _actions_initialized:
        return

    _ensure_action(negative_x_action, [KEY_A, KEY_LEFT])
    _ensure_action(positive_x_action, [KEY_D, KEY_RIGHT])
    _ensure_action(negative_z_action, [KEY_W, KEY_UP])
    _ensure_action(positive_z_action, [KEY_S, KEY_DOWN])
    _ensure_action(jump_action, [KEY_SPACE])
    _ensure_action(sprint_action, [KEY_SHIFT])

    _actions_initialized = true

func _ensure_action(action_name: StringName, keys: Array) -> void:
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name)

    var events := InputMap.action_get_events(action_name)
    if events.size() > 0:
        return

    for key_code in keys:
        var event := InputEventKey.new()
        event.physical_keycode = key_code
        InputMap.action_add_event(action_name, event)
