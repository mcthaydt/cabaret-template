extends RefCounted
class_name U_PostProcessLayer

## Helper for managing post-process ColorRects in the display overlay.

const EFFECT_FILM_GRAIN := StringName("film_grain")
const EFFECT_CRT := StringName("crt")
const EFFECT_DITHER := StringName("dither")
const EFFECT_COLOR_BLIND := StringName("color_blind")

const EFFECT_NODE_PATHS := {
	EFFECT_FILM_GRAIN: NodePath("FilmGrainLayer/FilmGrainRect"),
	EFFECT_CRT: NodePath("CRTLayer/CRTRect"),
	EFFECT_DITHER: NodePath("DitherLayer/DitherRect"),
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
