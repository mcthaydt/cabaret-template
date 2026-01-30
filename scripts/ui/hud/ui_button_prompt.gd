@icon("res://assets/editor_icons/icn_utility.svg")
extends HBoxContainer
class_name UI_ButtonPrompt

const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_ButtonPromptRegistry := preload("res://scripts/ui/utils/u_button_prompt_registry.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const M_InputDeviceManager := preload("res://scripts/managers/m_input_device_manager.gd")

@export var label_path: NodePath = NodePath("Text")
@export var text_icon_panel_path: NodePath = NodePath("TextIcon")
@export var text_icon_texture_path: NodePath = NodePath("TextIcon/ButtonIcon")
@export var text_icon_label_path: NodePath = NodePath("TextIcon/Label")
@export var mobile_button_path: NodePath = NodePath("MobileButton")
@export var mobile_button_label_path: NodePath = NodePath("MobileButton/ActionLabel")

@export var input_device_manager: M_InputDeviceManager = null

const INTERACT_COLOR := Color(1.0, 0.85, 0.6)

var _label: Label
var _text_icon_panel: Control
var _text_icon_texture: TextureRect
var _text_icon_label: Label
var _mobile_button: Control
var _mobile_button_label: Label
var _store: I_StateStore = null
var _device_manager: M_InputDeviceManager = null
var _tree_node_added_connected: bool = false
var _device_type: int = M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE
var _action: StringName = StringName("")
var _prompt_text: String = ""
var _is_shown: bool = false

func _ready() -> void:
	_label = get_node_or_null(label_path) as Label
	_text_icon_panel = get_node_or_null(text_icon_panel_path) as Control
	_text_icon_texture = get_node_or_null(text_icon_texture_path) as TextureRect
	_text_icon_label = get_node_or_null(text_icon_label_path) as Label
	_mobile_button = get_node_or_null(mobile_button_path) as Control
	_mobile_button_label = get_node_or_null(mobile_button_label_path) as Label
	_reset_visuals()
	_bind_store()
	_device_type = _get_initial_device_type()
	_bind_device_manager()
	_connect_tree_node_added_signal()

func _exit_tree() -> void:
	if _device_manager != null and is_instance_valid(_device_manager):
		var callable := Callable(self, "_on_device_changed_signal")
		if _device_manager.device_changed.is_connected(callable):
			_device_manager.device_changed.disconnect(callable)
	_device_manager = null
	if _tree_node_added_connected and get_tree() != null:
		var tree := get_tree()
		if tree.node_added.is_connected(_on_tree_node_added):
			tree.node_added.disconnect(_on_tree_node_added)
	_tree_node_added_connected = false

func show_prompt(action: StringName, prompt: String) -> void:
	_action = action
	_prompt_text = prompt
	_is_shown = true
	_device_type = _get_initial_device_type()
	_refresh_prompt()

func set_prompt_text(prompt: String) -> void:
	_prompt_text = prompt
	if _is_shown:
		_refresh_prompt()

func set_action(action: StringName) -> void:
	_action = action
	if _is_shown:
		_refresh_prompt()

func hide_prompt() -> void:
	_is_shown = false
	_reset_visuals()

func _bind_store() -> void:
	_store = U_StateUtils.get_store(self)

func _get_initial_device_type() -> int:
	if _store != null:
		var state := _store.get_state()
		return U_InputSelectors.get_active_device(state)
	return M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE

func _refresh_prompt() -> void:
	if not _is_shown:
		return
	var cleaned_prompt := _get_clean_prompt_text(_prompt_text)
	var binding_label := U_ButtonPromptRegistry.get_binding_label(_action, _device_type)
	var is_touchscreen := _device_type == M_InputDeviceManager.DeviceType.TOUCHSCREEN

	# Show mobile button for touchscreen, text icon for other devices
	if is_touchscreen:
		if _text_icon_panel != null:
			_text_icon_panel.visible = false
		if _mobile_button != null:
			_mobile_button.visible = true
			if _mobile_button_label != null:
				_mobile_button_label.text = binding_label if not binding_label.is_empty() else "Interact"
				_mobile_button_label.modulate = INTERACT_COLOR
	else:
		if _mobile_button != null:
			_mobile_button.visible = false

		if _text_icon_panel != null:
			# Try texture first, fall back to text
			var texture := U_ButtonPromptRegistry.get_prompt(_action, _device_type)
			var has_texture := texture != null
			var has_binding_label := not binding_label.is_empty()

			_text_icon_panel.visible = has_texture or has_binding_label

			if _text_icon_texture != null:
				if has_texture:
					_text_icon_texture.texture = texture
					_text_icon_texture.visible = true
					if _text_icon_label != null:
						_text_icon_label.visible = false
				else:
					_text_icon_texture.texture = null
					_text_icon_texture.visible = false
					if _text_icon_label != null:
						_text_icon_label.visible = has_binding_label
						_text_icon_label.text = binding_label if has_binding_label else ""
			else:
				# No texture node (backward compatible)
				if _text_icon_label != null:
					_text_icon_label.visible = has_binding_label
					_text_icon_label.text = binding_label if has_binding_label else ""

	if _label != null:
		_label.text = cleaned_prompt
		_label.visible = true

	visible = true

func _get_clean_prompt_text(prompt: String) -> String:
	var cleaned := String(prompt).strip_edges()
	if cleaned.is_empty():
		return "Interact"
	return cleaned

func _reset_visuals() -> void:
	if _label != null:
		_label.text = ""
		_label.visible = false
	if _text_icon_panel != null:
		_text_icon_panel.visible = false
	if _text_icon_texture != null:
		_text_icon_texture.texture = null
		_text_icon_texture.visible = false
	if _text_icon_label != null:
		_text_icon_label.text = ""
	if _mobile_button != null:
		_mobile_button.visible = false
	if _mobile_button_label != null:
		_mobile_button_label.text = ""
	visible = false

func _bind_device_manager() -> void:
	if _device_manager != null and is_instance_valid(_device_manager):
		return
	var manager: M_InputDeviceManager = null
	if input_device_manager != null and is_instance_valid(input_device_manager):
		manager = input_device_manager
	else:
		manager = U_ServiceLocator.try_get_service(StringName("input_device_manager")) as M_InputDeviceManager
		if manager == null:
			var tree := get_tree()
			if tree != null:
				manager = _find_device_manager_in_tree(tree)
	if manager == null:
		return
	_device_manager = manager
	var callable := Callable(self, "_on_device_changed_signal")
	if not _device_manager.device_changed.is_connected(callable):
		_device_manager.device_changed.connect(callable)

func _connect_tree_node_added_signal() -> void:
	if _tree_node_added_connected:
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.node_added.connect(_on_tree_node_added)
	_tree_node_added_connected = true

func _on_tree_node_added(node: Node) -> void:
	if node == null:
		return
	if node is M_InputDeviceManager:
		_bind_device_manager()

func _find_device_manager_in_tree(tree: SceneTree) -> M_InputDeviceManager:
	var root := tree.get_root()
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var candidate: Node = stack.pop_back()
		if candidate is M_InputDeviceManager:
			return candidate as M_InputDeviceManager
		for child in candidate.get_children():
			stack.append(child)
	return null

func _on_device_changed_signal(device_type: int, _device_id: int, _timestamp: float) -> void:
	_device_type = device_type
	if _is_shown:
		_refresh_prompt()
