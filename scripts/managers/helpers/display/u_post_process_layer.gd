extends RefCounted
class_name U_PostProcessLayer

## Helper for managing post-process ColorRects in the display overlay.
## Uses a single combined shader for film grain + dither + CRT,
## plus a separate color blind layer.

const EFFECT_COMBINED := StringName("combined")
const EFFECT_COLOR_BLIND := StringName("color_blind")

# Legacy constants kept for external references (tests, selectors)
const EFFECT_FILM_GRAIN := StringName("film_grain")
const EFFECT_CRT := StringName("crt")
const EFFECT_DITHER := StringName("dither")

const EFFECT_NODE_PATHS := {
	EFFECT_COMBINED: NodePath("CombinedLayer/CombinedRect"),
	EFFECT_COLOR_BLIND: NodePath("ColorBlindLayer/ColorBlindRect"),
}

var _effect_rects: Dictionary = {}

func initialize(root_node: Node) -> void:
	_effect_rects.clear()
	if root_node == null:
		return
	for effect_name in EFFECT_NODE_PATHS.keys():
		var path: NodePath = EFFECT_NODE_PATHS[effect_name]
		var rect := root_node.get_node_or_null(path) as ColorRect
		if rect != null:
			_effect_rects[effect_name] = rect

func get_effect_rect(effect_name: StringName) -> ColorRect:
	var rect: Variant = _effect_rects.get(effect_name)
	if rect is ColorRect:
		return rect as ColorRect
	return null

func get_combined_rect() -> ColorRect:
	return get_effect_rect(EFFECT_COMBINED)

func set_effect_enabled(effect_name: StringName, enabled: bool) -> void:
	var rect := get_effect_rect(effect_name)
	if rect == null:
		return
	rect.visible = enabled

func set_effect_parameter(effect_name: StringName, param: StringName, value: Variant) -> void:
	var rect := get_effect_rect(effect_name)
	if rect == null:
		return
	var material: Variant = rect.material
	if material == null or not (material is ShaderMaterial):
		return
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter(param, value)

func set_combined_parameter(param: StringName, value: Variant) -> void:
	set_effect_parameter(EFFECT_COMBINED, param, value)

func set_combined_visible(visible: bool) -> void:
	set_effect_enabled(EFFECT_COMBINED, visible)
