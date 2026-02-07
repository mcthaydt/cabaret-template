extends CanvasLayer
class_name SC_CinemaDebugOverlay

## Debug overlay for runtime cinema grade tuning
##
## Displays:
## - Current scene_id
## - Filter preset dropdown
## - All 13 cinema grade parameters as sliders
## - Reset to scene defaults button
## - Export to console button
##
## Toggled with F4 key via M_StateStore._input()

const U_StateUtils := preload("res://scripts/utils/u_state_utils.gd")
const U_CinemaGradeActions := preload("res://scripts/state/actions/u_cinema_grade_actions.gd")
const U_CinemaGradeSelectors := preload("res://scripts/state/selectors/u_cinema_grade_selectors.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_CinemaGradeRegistry := preload("res://scripts/managers/helpers/display/u_cinema_grade_registry.gd")
const RS_SceneCinemaGrade := preload("res://scripts/resources/display/rs_scene_cinema_grade.gd")

@onready var scene_label: Label = %SceneLabel
@onready var filter_preset_option: OptionButton = %FilterPresetOption
@onready var filter_intensity_slider: HSlider = %FilterIntensitySlider
@onready var filter_intensity_spinbox: SpinBox = %FilterIntensitySpinBox
@onready var exposure_slider: HSlider = %ExposureSlider
@onready var exposure_spinbox: SpinBox = %ExposureSpinBox
@onready var brightness_slider: HSlider = %BrightnessSlider
@onready var brightness_spinbox: SpinBox = %BrightnessSpinBox
@onready var contrast_slider: HSlider = %ContrastSlider
@onready var contrast_spinbox: SpinBox = %ContrastSpinBox
@onready var brilliance_slider: HSlider = %BrillianceSlider
@onready var brilliance_spinbox: SpinBox = %BrillianceSpinBox
@onready var highlights_slider: HSlider = %HighlightsSlider
@onready var highlights_spinbox: SpinBox = %HighlightsSpinBox
@onready var shadows_slider: HSlider = %ShadowsSlider
@onready var shadows_spinbox: SpinBox = %ShadowsSpinBox
@onready var saturation_slider: HSlider = %SaturationSlider
@onready var saturation_spinbox: SpinBox = %SaturationSpinBox
@onready var vibrance_slider: HSlider = %VibranceSlider
@onready var vibrance_spinbox: SpinBox = %VibranceSpinBox
@onready var warmth_slider: HSlider = %WarmthSlider
@onready var warmth_spinbox: SpinBox = %WarmthSpinBox
@onready var tint_slider: HSlider = %TintSlider
@onready var tint_spinbox: SpinBox = %TintSpinBox
@onready var sharpness_slider: HSlider = %SharpnessSlider
@onready var sharpness_spinbox: SpinBox = %SharpnessSpinBox
@onready var reset_button: Button = %ResetButton
@onready var export_button: Button = %ExportButton

var _store: I_StateStore = null
var _updating_ui: bool = false
var _current_scene_id: StringName = StringName("")

func _ready() -> void:
	# CanvasLayer with PROCESS_MODE_ALWAYS to work even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	# Wait for scene tree to be fully ready
	await get_tree().process_frame

	# Find M_StateStore
	_store = U_StateUtils.try_get_store()
	if not _store:
		push_error("SC_CinemaDebugOverlay: Could not find M_StateStore")
		return

	# Subscribe to store signals
	_store.slice_updated.connect(_on_slice_updated)
	_store.action_dispatched.connect(_on_action_dispatched)

	# Connect UI signals
	_connect_ui_signals()

	# Initialize filter preset dropdown
	_initialize_filter_preset_dropdown()

	# Initial state load
	_load_state_into_ui()
	_update_visibility()

func _exit_tree() -> void:
	# Unsubscribe to prevent leaks
	if _store and is_instance_valid(_store):
		if _store.slice_updated.is_connected(_on_slice_updated):
			_store.slice_updated.disconnect(_on_slice_updated)
		if _store.action_dispatched.is_connected(_on_action_dispatched):
			_store.action_dispatched.disconnect(_on_action_dispatched)

func _connect_ui_signals() -> void:
	# Filter
	filter_preset_option.item_selected.connect(_on_filter_preset_selected)
	filter_intensity_slider.value_changed.connect(_on_filter_intensity_changed)
	filter_intensity_spinbox.value_changed.connect(_on_filter_intensity_changed)

	# Exposure & Brightness
	exposure_slider.value_changed.connect(_on_exposure_changed)
	exposure_spinbox.value_changed.connect(_on_exposure_changed)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	brightness_spinbox.value_changed.connect(_on_brightness_changed)
	contrast_slider.value_changed.connect(_on_contrast_changed)
	contrast_spinbox.value_changed.connect(_on_contrast_changed)
	brilliance_slider.value_changed.connect(_on_brilliance_changed)
	brilliance_spinbox.value_changed.connect(_on_brilliance_changed)

	# Tone
	highlights_slider.value_changed.connect(_on_highlights_changed)
	highlights_spinbox.value_changed.connect(_on_highlights_changed)
	shadows_slider.value_changed.connect(_on_shadows_changed)
	shadows_spinbox.value_changed.connect(_on_shadows_changed)

	# Color
	saturation_slider.value_changed.connect(_on_saturation_changed)
	saturation_spinbox.value_changed.connect(_on_saturation_changed)
	vibrance_slider.value_changed.connect(_on_vibrance_changed)
	vibrance_spinbox.value_changed.connect(_on_vibrance_changed)
	warmth_slider.value_changed.connect(_on_warmth_changed)
	warmth_spinbox.value_changed.connect(_on_warmth_changed)
	tint_slider.value_changed.connect(_on_tint_changed)
	tint_spinbox.value_changed.connect(_on_tint_changed)

	# Detail
	sharpness_slider.value_changed.connect(_on_sharpness_changed)
	sharpness_spinbox.value_changed.connect(_on_sharpness_changed)

	# Buttons
	reset_button.pressed.connect(_on_reset_pressed)
	export_button.pressed.connect(_on_export_pressed)

func _initialize_filter_preset_dropdown() -> void:
	filter_preset_option.clear()
	filter_preset_option.add_item("none", 0)
	filter_preset_option.add_item("dramatic", 1)
	filter_preset_option.add_item("dramatic_warm", 2)
	filter_preset_option.add_item("dramatic_cold", 3)
	filter_preset_option.add_item("vivid", 4)
	filter_preset_option.add_item("vivid_warm", 5)
	filter_preset_option.add_item("vivid_cold", 6)
	filter_preset_option.add_item("black_and_white", 7)
	filter_preset_option.add_item("sepia", 8)

func _on_slice_updated(slice_name: StringName, _slice_data: Dictionary) -> void:
	if slice_name == &"display" or slice_name == &"navigation":
		_load_state_into_ui()
		_update_visibility()

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: Variant = action.get("type", StringName(""))
	if action_type == StringName("scene/transition_completed"):
		# Reload UI when scene changes
		_load_state_into_ui()

func _load_state_into_ui() -> void:
	if not _store or _updating_ui:
		return

	_updating_ui = true

	var state := _store.get_state()
	var scene_slice := state.get("scene", {})
	_current_scene_id = scene_slice.get("current_scene_id", StringName(""))

	# Update scene label
	scene_label.text = "Scene: %s" % _current_scene_id

	# Update filter preset dropdown
	var filter_mode := U_CinemaGradeSelectors.get_filter_mode(state)
	filter_preset_option.selected = filter_mode

	# Update all sliders/spinboxes (use set_value_no_signal to avoid feedback loop)
	_set_slider_value(filter_intensity_slider, filter_intensity_spinbox, U_CinemaGradeSelectors.get_filter_intensity(state))
	_set_slider_value(exposure_slider, exposure_spinbox, U_CinemaGradeSelectors.get_exposure(state))
	_set_slider_value(brightness_slider, brightness_spinbox, U_CinemaGradeSelectors.get_brightness(state))
	_set_slider_value(contrast_slider, contrast_spinbox, U_CinemaGradeSelectors.get_contrast(state))
	_set_slider_value(brilliance_slider, brilliance_spinbox, U_CinemaGradeSelectors.get_brilliance(state))
	_set_slider_value(highlights_slider, highlights_spinbox, U_CinemaGradeSelectors.get_highlights(state))
	_set_slider_value(shadows_slider, shadows_spinbox, U_CinemaGradeSelectors.get_shadows(state))
	_set_slider_value(saturation_slider, saturation_spinbox, U_CinemaGradeSelectors.get_saturation(state))
	_set_slider_value(vibrance_slider, vibrance_spinbox, U_CinemaGradeSelectors.get_vibrance(state))
	_set_slider_value(warmth_slider, warmth_spinbox, U_CinemaGradeSelectors.get_warmth(state))
	_set_slider_value(tint_slider, tint_spinbox, U_CinemaGradeSelectors.get_tint(state))
	_set_slider_value(sharpness_slider, sharpness_spinbox, U_CinemaGradeSelectors.get_sharpness(state))

	_updating_ui = false

func _set_slider_value(slider: HSlider, spinbox: SpinBox, value: float) -> void:
	slider.set_value_no_signal(value)
	spinbox.set_value_no_signal(value)

func _update_visibility() -> void:
	if not _store:
		return

	var state := _store.get_state()
	var nav_slice := state.get("navigation", {})
	var shell := nav_slice.get("shell", StringName(""))

	# Show only during gameplay shell
	visible = (shell == StringName("gameplay"))

func _on_filter_preset_selected(index: int) -> void:
	if _updating_ui or not _store:
		return

	var preset_name := filter_preset_option.get_item_text(index)
	_store.dispatch(U_CinemaGradeActions.set_parameter("filter_preset", preset_name))

func _on_filter_intensity_changed(value: float) -> void:
	if _updating_ui or not _store:
		return
	_store.dispatch(U_CinemaGradeActions.set_parameter("filter_intensity", value))

func _on_exposure_changed(value: float) -> void:
	if _updating_ui or not _store:
		return
	_store.dispatch(U_CinemaGradeActions.set_parameter("exposure", value))

func _on_brightness_changed(value: float) -> void:
	if _updating_ui or not _store:
		return
	_store.dispatch(U_CinemaGradeActions.set_parameter("brightness", value))

func _on_contrast_changed(value: float) -> void:
	if _updating_ui or not _store:
		return
	_store.dispatch(U_CinemaGradeActions.set_parameter("contrast", value))

func _on_brilliance_changed(value: float) -> void:
	if _updating_ui or not _store:
		return
	_store.dispatch(U_CinemaGradeActions.set_parameter("brilliance", value))

func _on_highlights_changed(value: float) -> void:
	if _updating_ui or not _store:
		return
	_store.dispatch(U_CinemaGradeActions.set_parameter("highlights", value))

func _on_shadows_changed(value: float) -> void:
	if _updating_ui or not _store:
		return
	_store.dispatch(U_CinemaGradeActions.set_parameter("shadows", value))

func _on_saturation_changed(value: float) -> void:
	if _updating_ui or not _store:
		return
	_store.dispatch(U_CinemaGradeActions.set_parameter("saturation", value))

func _on_vibrance_changed(value: float) -> void:
	if _updating_ui or not _store:
		return
	_store.dispatch(U_CinemaGradeActions.set_parameter("vibrance", value))

func _on_warmth_changed(value: float) -> void:
	if _updating_ui or not _store:
		return
	_store.dispatch(U_CinemaGradeActions.set_parameter("warmth", value))

func _on_tint_changed(value: float) -> void:
	if _updating_ui or not _store:
		return
	_store.dispatch(U_CinemaGradeActions.set_parameter("tint", value))

func _on_sharpness_changed(value: float) -> void:
	if _updating_ui or not _store:
		return
	_store.dispatch(U_CinemaGradeActions.set_parameter("sharpness", value))

func _on_reset_pressed() -> void:
	if not _store:
		return

	var grade := U_CinemaGradeRegistry.get_cinema_grade_for_scene(_current_scene_id)
	if grade:
		_store.dispatch(U_CinemaGradeActions.reset_to_scene_defaults(grade.to_dictionary()))

func _on_export_pressed() -> void:
	if not _store:
		return

	var state := _store.get_state()
	var filter_mode := U_CinemaGradeSelectors.get_filter_mode(state)

	# Reverse-lookup filter preset name
	var filter_preset_name := "none"
	for key in RS_SceneCinemaGrade.FILTER_PRESET_MAP.keys():
		if RS_SceneCinemaGrade.FILTER_PRESET_MAP[key] == filter_mode:
			filter_preset_name = key
			break

	# Build .tres format string
	var tres_content := """[gd_resource type="Resource" script_class="RS_SceneCinemaGrade" format=3]

[ext_resource type="Script" path="res://scripts/resources/display/rs_scene_cinema_grade.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
scene_id = &"%s"
filter_preset = "%s"
filter_intensity = %s
exposure = %s
brightness = %s
contrast = %s
brilliance = %s
highlights = %s
shadows = %s
saturation = %s
vibrance = %s
warmth = %s
tint = %s
sharpness = %s
""" % [
		_current_scene_id,
		filter_preset_name,
		U_CinemaGradeSelectors.get_filter_intensity(state),
		U_CinemaGradeSelectors.get_exposure(state),
		U_CinemaGradeSelectors.get_brightness(state),
		U_CinemaGradeSelectors.get_contrast(state),
		U_CinemaGradeSelectors.get_brilliance(state),
		U_CinemaGradeSelectors.get_highlights(state),
		U_CinemaGradeSelectors.get_shadows(state),
		U_CinemaGradeSelectors.get_saturation(state),
		U_CinemaGradeSelectors.get_vibrance(state),
		U_CinemaGradeSelectors.get_warmth(state),
		U_CinemaGradeSelectors.get_tint(state),
		U_CinemaGradeSelectors.get_sharpness(state)
	]

	# Print to console with color
	print_rich("[color=cyan]===== Cinema Grade Export for scene: %s =====[/color]" % _current_scene_id)
	print(tres_content)
	print_rich("[color=green]Copy the above and paste into: resources/display/cinema_grades/cfg_cinema_grade_%s.tres[/color]" % _current_scene_id)
