extends RefCounted
class_name U_DisplayUIScaleApplier

## Applies UI scale to registered roots and their descendants.

var _min_ui_scale: float = 0.8
var _max_ui_scale: float = 1.3
var _current_ui_scale: float = 1.0
var _ui_scale_roots: Array[Node] = []

func initialize(min_scale: float, max_scale: float) -> void:
	_min_ui_scale = min_scale
	_max_ui_scale = max_scale

func set_ui_scale(scale: float) -> float:
	var clamped_scale := clampf(scale, _min_ui_scale, _max_ui_scale)
	_current_ui_scale = clamped_scale
	if _ui_scale_roots.is_empty():
		return clamped_scale
	var valid_roots: Array[Node] = []
	for node in _ui_scale_roots:
		if node == null or not is_instance_valid(node):
			continue
		valid_roots.append(node)
		_apply_ui_scale_to_node(node, clamped_scale)
	_ui_scale_roots = valid_roots
	return clamped_scale

func get_current_scale() -> float:
	return _current_ui_scale

func get_roots() -> Array[Node]:
	return _ui_scale_roots.duplicate()

func register_ui_scale_root(node: Node) -> void:
	if node == null:
		return
	if _ui_scale_roots.has(node):
		return
	_ui_scale_roots.append(node)
	_apply_ui_scale_to_node(node, _current_ui_scale)

func unregister_ui_scale_root(node: Node) -> void:
	if node == null:
		return
	_ui_scale_roots.erase(node)

func _apply_ui_scale_to_node(node: Node, scale: float) -> void:
	if node is CanvasLayer:
		_apply_font_scale_to_tree(node, scale)
		return
	if node is Control:
		# Safe area padding disabled - it interferes with fullscreen overlays
		# UI elements should use proper anchors instead
		_apply_font_scale_to_tree(node, scale)
		return
	_apply_font_scale_to_tree(node, scale)

func _apply_font_scale_to_tree(node: Node, scale: float) -> void:
	if node == null:
		return
	if node is Control:
		_apply_font_scale_to_control(node as Control, scale)
	var children: Array = node.get_children()
	for child in children:
		if child is Node:
			_apply_font_scale_to_tree(child, scale)

func _apply_font_scale_to_control(control: Control, scale: float) -> void:
	if control == null:
		return
	var base_size: int = _get_font_base_size(control)
	if base_size <= 0:
		return
	var scaled_size: int = int(round(float(base_size) * scale))
	if scaled_size <= 0:
		scaled_size = 1
	control.add_theme_font_size_override("font_size", scaled_size)

func _get_font_base_size(control: Control) -> int:
	if control == null:
		return 0
	var meta_key: StringName = StringName("ui_scale_font_base")
	if control.has_meta(meta_key):
		return int(control.get_meta(meta_key))
	var base_size: int = control.get_theme_font_size("font_size")
	control.set_meta(meta_key, base_size)
	return base_size
