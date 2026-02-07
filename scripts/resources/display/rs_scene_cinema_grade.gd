@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_SceneCinemaGrade

## Per-scene cinema grade configuration for artistic color grading.
##
## Each gameplay scene can have a unique look defined by adjustments
## (exposure, contrast, saturation, etc.) and optional named filters.

@export var scene_id: StringName = StringName("")

@export_group("Filter")
@export_enum("none", "dramatic", "dramatic_warm", "dramatic_cold", "vivid", "vivid_warm", "vivid_cold", "black_and_white", "sepia") var filter_preset: String = "none"
@export_range(0.0, 1.0, 0.01) var filter_intensity: float = 1.0

@export_group("Exposure & Brightness")
@export_range(-3.0, 3.0, 0.01) var exposure: float = 0.0
@export_range(-1.0, 1.0, 0.01) var brightness: float = 0.0
@export_range(0.0, 3.0, 0.01) var contrast: float = 1.0
@export_range(-1.0, 1.0, 0.01) var brilliance: float = 0.0

@export_group("Tone")
@export_range(-1.0, 1.0, 0.01) var highlights: float = 0.0
@export_range(-1.0, 1.0, 0.01) var shadows: float = 0.0

@export_group("Color")
@export_range(0.0, 3.0, 0.01) var saturation: float = 1.0
@export_range(-1.0, 1.0, 0.01) var vibrance: float = 0.0
@export_range(-1.0, 1.0, 0.01) var warmth: float = 0.0
@export_range(-1.0, 1.0, 0.01) var tint: float = 0.0

@export_group("Detail")
@export_range(0.0, 2.0, 0.01) var sharpness: float = 0.0

const FILTER_PRESET_MAP := {
	"none": 0,
	"dramatic": 1,
	"dramatic_warm": 2,
	"dramatic_cold": 3,
	"vivid": 4,
	"vivid_warm": 5,
	"vivid_cold": 6,
	"black_and_white": 7,
	"sepia": 8,
}

func to_dictionary() -> Dictionary:
	return {
		"cinema_grade_filter_mode": FILTER_PRESET_MAP.get(filter_preset, 0),
		"cinema_grade_filter_intensity": filter_intensity,
		"cinema_grade_exposure": exposure,
		"cinema_grade_brightness": brightness,
		"cinema_grade_contrast": contrast,
		"cinema_grade_brilliance": brilliance,
		"cinema_grade_highlights": highlights,
		"cinema_grade_shadows": shadows,
		"cinema_grade_saturation": saturation,
		"cinema_grade_vibrance": vibrance,
		"cinema_grade_warmth": warmth,
		"cinema_grade_tint": tint,
		"cinema_grade_sharpness": sharpness,
	}
