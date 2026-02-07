@tool
@icon("res://assets/editor_icons/icn_utility.svg")
extends Node
class_name U_CinemaGradePreview

## Editor-only preview node for cinema grade effects.
##
## Drop into any gameplay scene root, assign a RS_SceneCinemaGrade resource,
## and see the effect live in the editor viewport. Removes itself at runtime
## (M_DisplayManager handles everything in-game).

const CINEMA_GRADE_SHADER := preload("res://assets/shaders/sh_cinema_grade_shader.gdshader")

@export var cinema_grade: Resource = null:
	set(value):
		cinema_grade = value
		if Engine.is_editor_hint():
			_update_preview()

var _preview_layer: CanvasLayer = null
var _preview_rect: ColorRect = null
var _shader_material: ShaderMaterial = null

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	_setup_preview()
	_update_preview()

func _setup_preview() -> void:
	if _preview_layer != null:
		return

	_preview_layer = CanvasLayer.new()
	_preview_layer.name = "CinemaGradePreviewLayer"
	_preview_layer.layer = 100

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = CINEMA_GRADE_SHADER

	_preview_rect = ColorRect.new()
	_preview_rect.name = "CinemaGradePreviewRect"
	_preview_rect.material = _shader_material
	_preview_rect.anchors_preset = Control.PRESET_FULL_RECT
	_preview_rect.anchor_right = 1.0
	_preview_rect.anchor_bottom = 1.0
	_preview_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_preview_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	_preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_preview_layer.add_child(_preview_rect)
	add_child(_preview_layer)

func _update_preview() -> void:
	if _shader_material == null:
		return
	if cinema_grade == null:
		_preview_rect.visible = false
		return

	_preview_rect.visible = true

	var grade := cinema_grade as Resource

	# Use RS_SceneCinemaGrade.FILTER_PRESET_MAP (single source of truth)
	const RS_SceneCinemaGrade := preload("res://scripts/resources/display/rs_scene_cinema_grade.gd")
	var filter_preset: String = grade.get("filter_preset") if grade.get("filter_preset") != null else "none"
	_shader_material.set_shader_parameter("filter_mode", RS_SceneCinemaGrade.FILTER_PRESET_MAP.get(filter_preset, 0))
	_shader_material.set_shader_parameter("filter_intensity", _get_prop(grade, "filter_intensity", 1.0))
	_shader_material.set_shader_parameter("exposure", _get_prop(grade, "exposure", 0.0))
	_shader_material.set_shader_parameter("brightness", _get_prop(grade, "brightness", 0.0))
	_shader_material.set_shader_parameter("contrast", _get_prop(grade, "contrast", 1.0))
	_shader_material.set_shader_parameter("brilliance", _get_prop(grade, "brilliance", 0.0))
	_shader_material.set_shader_parameter("highlights", _get_prop(grade, "highlights", 0.0))
	_shader_material.set_shader_parameter("shadows", _get_prop(grade, "shadows", 0.0))
	_shader_material.set_shader_parameter("saturation", _get_prop(grade, "saturation", 1.0))
	_shader_material.set_shader_parameter("vibrance", _get_prop(grade, "vibrance", 0.0))
	_shader_material.set_shader_parameter("warmth", _get_prop(grade, "warmth", 0.0))
	_shader_material.set_shader_parameter("tint", _get_prop(grade, "tint", 0.0))
	_shader_material.set_shader_parameter("sharpness", _get_prop(grade, "sharpness", 0.0))

func _get_prop(res: Resource, prop_name: String, default_value: Variant) -> Variant:
	var value: Variant = res.get(prop_name)
	if value == null:
		return default_value
	return value

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if cinema_grade == null:
		warnings.append("No cinema grade resource assigned. Assign a RS_SceneCinemaGrade resource to see the preview.")
	return warnings
