@icon("res://assets/editor_icons/icn_utility.svg")
extends VBoxContainer
class_name UI_DisplaySettingsTab

const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_DisplayUtils := preload("res://scripts/utils/display/u_display_utils.gd")
const U_DisplayOptionCatalog := preload("res://scripts/utils/display/u_display_option_catalog.gd")
const U_DisplaySelectors := preload("res://scripts/state/selectors/u_display_selectors.gd")
const U_DisplayActions := preload("res://scripts/state/actions/u_display_actions.gd")
const U_FocusConfigurator := preload("res://scripts/ui/helpers/u_focus_configurator.gd")
const U_UISoundPlayer := preload("res://scripts/ui/utils/u_ui_sound_player.gd")
const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const RS_DisplayInitialState := preload("res://scripts/resources/state/rs_display_initial_state.gd")
const RS_LUT_DEFINITION := preload("res://scripts/resources/display/rs_lut_definition.gd")
const DEFAULT_DISPLAY_INITIAL_STATE: Resource = preload("res://resources/base_settings/state/cfg_display_initial_state.tres")

var _state_store: I_StateStore = null
var _display_manager: I_DisplayManager = null
var _unsubscribe: Callable = Callable()
var _updating_from_state: bool = false
var _has_local_edits: bool = false

var _window_size_values: Array[String] = []
var _window_mode_values: Array[String] = []
var _quality_preset_values: Array[String] = []
var _dither_pattern_values: Array[String] = []
var _color_blind_mode_values: Array[String] = []
var _lut_resource_values: Array[String] = []

@onready var _window_size_option: OptionButton = %WindowSizeOption
@onready var _window_mode_option: OptionButton = %WindowModeOption
@onready var _vsync_toggle: CheckBox = %VSyncToggle
@onready var _quality_preset_option: OptionButton = %QualityPresetOption

@onready var _film_grain_toggle: CheckBox = %FilmGrainToggle
@onready var _film_grain_intensity_slider: HSlider = %FilmGrainIntensitySlider
@onready var _film_grain_intensity_value: Label = %FilmGrainIntensityValue

@onready var _crt_toggle: CheckBox = %CRTToggle
@onready var _crt_scanline_slider: HSlider = %CRTScanlineSlider
@onready var _crt_scanline_value: Label = %CRTScanlineValue
@onready var _crt_curvature_slider: HSlider = %CRTCurvatureSlider
@onready var _crt_curvature_value: Label = %CRTCurvatureValue
@onready var _crt_aberration_slider: HSlider = %CRTAberrationSlider
@onready var _crt_aberration_value: Label = %CRTAberrationValue

@onready var _dither_toggle: CheckBox = %DitherToggle
@onready var _dither_intensity_slider: HSlider = %DitherIntensitySlider
@onready var _dither_intensity_value: Label = %DitherIntensityValue
@onready var _dither_pattern_option: OptionButton = %DitherPatternOption

@onready var _lut_toggle: CheckBox = %LUTToggle
@onready var _lut_option: OptionButton = %LUTOption
@onready var _lut_intensity_slider: HSlider = %LUTIntensitySlider
@onready var _lut_intensity_value: Label = %LUTIntensityValue

@onready var _ui_scale_slider: HSlider = %UIScaleSlider
@onready var _ui_scale_value: Label = %UIScaleValue

@onready var _color_blind_mode_option: OptionButton = %ColorBlindModeOption
@onready var _high_contrast_toggle: CheckBox = %HighContrastToggle
@onready var _color_blind_shader_toggle: CheckBox = %ColorBlindShaderToggle

@onready var _cancel_button: Button = %CancelButton
@onready var _reset_button: Button = %ResetButton
@onready var _apply_button: Button = %ApplyButton

func _ready() -> void:
	_connect_signals()
	_populate_option_buttons()
	_configure_focus_neighbors()

	_state_store = U_StateUtils.get_store(self)
	if _state_store == null:
		push_error("UI_DisplaySettingsTab: StateStore not found")
		return

	_display_manager = U_DisplayUtils.get_display_manager()

	_unsubscribe = _state_store.subscribe(_on_state_changed)
	_on_state_changed({}, _state_store.get_state())

func _exit_tree() -> void:
	_clear_display_settings_preview()
	if _unsubscribe != Callable() and _unsubscribe.is_valid():
		_unsubscribe.call()
		_unsubscribe = Callable()

func _connect_signals() -> void:
	if _window_size_option != null and not _window_size_option.item_selected.is_connected(_on_window_size_selected):
		_window_size_option.item_selected.connect(_on_window_size_selected)
	if _window_mode_option != null and not _window_mode_option.item_selected.is_connected(_on_window_mode_selected):
		_window_mode_option.item_selected.connect(_on_window_mode_selected)
	if _vsync_toggle != null and not _vsync_toggle.toggled.is_connected(_on_vsync_toggled):
		_vsync_toggle.toggled.connect(_on_vsync_toggled)
	if _quality_preset_option != null and not _quality_preset_option.item_selected.is_connected(_on_quality_preset_selected):
		_quality_preset_option.item_selected.connect(_on_quality_preset_selected)

	if _film_grain_toggle != null and not _film_grain_toggle.toggled.is_connected(_on_film_grain_toggled):
		_film_grain_toggle.toggled.connect(_on_film_grain_toggled)
	if _film_grain_intensity_slider != null and not _film_grain_intensity_slider.value_changed.is_connected(_on_film_grain_intensity_changed):
		_film_grain_intensity_slider.value_changed.connect(_on_film_grain_intensity_changed)

	if _crt_toggle != null and not _crt_toggle.toggled.is_connected(_on_crt_toggled):
		_crt_toggle.toggled.connect(_on_crt_toggled)
	if _crt_scanline_slider != null and not _crt_scanline_slider.value_changed.is_connected(_on_crt_scanline_changed):
		_crt_scanline_slider.value_changed.connect(_on_crt_scanline_changed)
	if _crt_curvature_slider != null and not _crt_curvature_slider.value_changed.is_connected(_on_crt_curvature_changed):
		_crt_curvature_slider.value_changed.connect(_on_crt_curvature_changed)
	if _crt_aberration_slider != null and not _crt_aberration_slider.value_changed.is_connected(_on_crt_aberration_changed):
		_crt_aberration_slider.value_changed.connect(_on_crt_aberration_changed)

	if _dither_toggle != null and not _dither_toggle.toggled.is_connected(_on_dither_toggled):
		_dither_toggle.toggled.connect(_on_dither_toggled)
	if _dither_intensity_slider != null and not _dither_intensity_slider.value_changed.is_connected(_on_dither_intensity_changed):
		_dither_intensity_slider.value_changed.connect(_on_dither_intensity_changed)
	if _dither_pattern_option != null and not _dither_pattern_option.item_selected.is_connected(_on_dither_pattern_selected):
		_dither_pattern_option.item_selected.connect(_on_dither_pattern_selected)

	if _lut_toggle != null and not _lut_toggle.toggled.is_connected(_on_lut_toggled):
		_lut_toggle.toggled.connect(_on_lut_toggled)
	if _lut_option != null and not _lut_option.item_selected.is_connected(_on_lut_selected):
		_lut_option.item_selected.connect(_on_lut_selected)
	if _lut_intensity_slider != null and not _lut_intensity_slider.value_changed.is_connected(_on_lut_intensity_changed):
		_lut_intensity_slider.value_changed.connect(_on_lut_intensity_changed)

	if _ui_scale_slider != null and not _ui_scale_slider.value_changed.is_connected(_on_ui_scale_changed):
		_ui_scale_slider.value_changed.connect(_on_ui_scale_changed)

	if _color_blind_mode_option != null and not _color_blind_mode_option.item_selected.is_connected(_on_color_blind_mode_selected):
		_color_blind_mode_option.item_selected.connect(_on_color_blind_mode_selected)
	if _high_contrast_toggle != null and not _high_contrast_toggle.toggled.is_connected(_on_high_contrast_toggled):
		_high_contrast_toggle.toggled.connect(_on_high_contrast_toggled)
	if _color_blind_shader_toggle != null and not _color_blind_shader_toggle.toggled.is_connected(_on_color_blind_shader_toggled):
		_color_blind_shader_toggle.toggled.connect(_on_color_blind_shader_toggled)

	if _cancel_button != null and not _cancel_button.pressed.is_connected(_on_cancel_pressed):
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if _reset_button != null and not _reset_button.pressed.is_connected(_on_reset_pressed):
		_reset_button.pressed.connect(_on_reset_pressed)
	if _apply_button != null and not _apply_button.pressed.is_connected(_on_apply_pressed):
		_apply_button.pressed.connect(_on_apply_pressed)

func _populate_option_buttons() -> void:
	_populate_option_button(
		_window_size_option,
		U_DisplayOptionCatalog.get_window_size_option_entries(),
		_window_size_values
	)
	_populate_option_button(
		_window_mode_option,
		U_DisplayOptionCatalog.get_window_mode_option_entries(),
		_window_mode_values
	)
	_populate_option_button(
		_quality_preset_option,
		U_DisplayOptionCatalog.get_quality_option_entries(),
		_quality_preset_values
	)
	_populate_option_button(
		_dither_pattern_option,
		U_DisplayOptionCatalog.get_dither_pattern_option_entries(),
		_dither_pattern_values
	)
	_populate_option_button(
		_color_blind_mode_option,
		U_DisplayOptionCatalog.get_color_blind_mode_option_entries(),
		_color_blind_mode_values
	)
	_populate_lut_options()

func _populate_option_button(button: OptionButton, options: Array, values: Array[String]) -> void:
	if button == null:
		return
	button.clear()
	values.clear()
	for option in options:
		if option is Dictionary:
			var entry := option as Dictionary
			var label := String(entry.get("label", ""))
			var value := String(entry.get("id", ""))
			if label.is_empty():
				label = value
			button.add_item(label)
			values.append(value)

func _populate_lut_options() -> void:
	if _lut_option == null:
		return

	_lut_option.clear()
	_lut_resource_values.clear()

	_lut_option.add_item("None")
	_lut_resource_values.append("")

	var definition_paths: Array[String] = []
	var texture_paths: Array[String] = []
	var used_textures: Dictionary = {}
	var dir := DirAccess.open("res://resources/luts")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".tres"):
					var path := "res://resources/luts/" + file_name
					definition_paths.append(path)
				elif file_name.ends_with(".png"):
					var texture_path := "res://resources/luts/" + file_name
					texture_paths.append(texture_path)
			file_name = dir.get_next()
		dir.list_dir_end()

	definition_paths.sort()
	texture_paths.sort()

	for path in definition_paths:
		var resource := load(path)
		if resource == null:
			continue
		if resource is RS_LUT_DEFINITION:
			var definition := resource as RS_LUT_DEFINITION
			var label := definition.display_name
			if label.is_empty():
				label = path.get_file().trim_suffix(".tres")
			_lut_option.add_item(label)
			_lut_resource_values.append(path)
			if definition.texture != null:
				var texture_path := definition.texture.resource_path
				if texture_path != "":
					used_textures[texture_path] = true

	for texture_path in texture_paths:
		if used_textures.has(texture_path):
			continue
		var texture_label := texture_path.get_file().trim_suffix(".png")
		_lut_option.add_item(texture_label)
		_lut_resource_values.append(texture_path)

func _configure_focus_neighbors() -> void:
	var focusables: Array[Control] = []
	if _window_size_option != null:
		focusables.append(_window_size_option)
	if _window_mode_option != null:
		focusables.append(_window_mode_option)
	if _vsync_toggle != null:
		focusables.append(_vsync_toggle)
	if _quality_preset_option != null:
		focusables.append(_quality_preset_option)

	if _film_grain_toggle != null:
		focusables.append(_film_grain_toggle)
	if _film_grain_intensity_slider != null:
		focusables.append(_film_grain_intensity_slider)
	if _crt_toggle != null:
		focusables.append(_crt_toggle)
	if _crt_scanline_slider != null:
		focusables.append(_crt_scanline_slider)
	if _crt_curvature_slider != null:
		focusables.append(_crt_curvature_slider)
	if _crt_aberration_slider != null:
		focusables.append(_crt_aberration_slider)
	if _dither_toggle != null:
		focusables.append(_dither_toggle)
	if _dither_intensity_slider != null:
		focusables.append(_dither_intensity_slider)
	if _dither_pattern_option != null:
		focusables.append(_dither_pattern_option)
	if _lut_toggle != null:
		focusables.append(_lut_toggle)
	if _lut_option != null:
		focusables.append(_lut_option)
	if _lut_intensity_slider != null:
		focusables.append(_lut_intensity_slider)

	if _ui_scale_slider != null:
		focusables.append(_ui_scale_slider)
	if _color_blind_mode_option != null:
		focusables.append(_color_blind_mode_option)
	if _high_contrast_toggle != null:
		focusables.append(_high_contrast_toggle)
	if _color_blind_shader_toggle != null:
		focusables.append(_color_blind_shader_toggle)

	if not focusables.is_empty():
		U_FocusConfigurator.configure_vertical_focus(focusables, false)

	var buttons: Array[Control] = []
	if _cancel_button != null:
		buttons.append(_cancel_button)
	if _reset_button != null:
		buttons.append(_reset_button)
	if _apply_button != null:
		buttons.append(_apply_button)

	if not buttons.is_empty():
		U_FocusConfigurator.configure_horizontal_focus(buttons, true)
		var last_focus := focusables[focusables.size() - 1] if not focusables.is_empty() else null
		if last_focus != null:
			last_focus.focus_neighbor_bottom = last_focus.get_path_to(buttons[0])
			for button in buttons:
				button.focus_neighbor_top = button.get_path_to(last_focus)
				button.focus_neighbor_bottom = button.get_path_to(last_focus)

func _on_state_changed(action: Dictionary, state: Dictionary) -> void:
	if state == null:
		return

	var action_type: StringName = StringName("")
	if action != null and action.has("type"):
		action_type = action.get("type", StringName(""))

	# Preserve local edits (Apply/Cancel pattern). Only reconcile from state when
	# the user is not actively editing.
	if _has_local_edits and action_type != StringName(""):
		return

	_updating_from_state = true

	_select_option_value(_window_size_option, _window_size_values, U_DisplaySelectors.get_window_size_preset(state))
	_select_option_value(_window_mode_option, _window_mode_values, U_DisplaySelectors.get_window_mode(state))
	_set_toggle_value_silently(_vsync_toggle, U_DisplaySelectors.is_vsync_enabled(state))
	_select_option_value(_quality_preset_option, _quality_preset_values, U_DisplaySelectors.get_quality_preset(state))

	_set_toggle_value_silently(_film_grain_toggle, U_DisplaySelectors.is_film_grain_enabled(state))
	var film_grain_intensity := U_DisplaySelectors.get_film_grain_intensity(state)
	_set_slider_value_silently(_film_grain_intensity_slider, film_grain_intensity)
	_update_percentage_label(_film_grain_intensity_value, film_grain_intensity)

	_set_toggle_value_silently(_crt_toggle, U_DisplaySelectors.is_crt_enabled(state))
	var scanline_intensity := U_DisplaySelectors.get_crt_scanline_intensity(state)
	_set_slider_value_silently(_crt_scanline_slider, scanline_intensity)
	_update_percentage_label(_crt_scanline_value, scanline_intensity)

	var curvature := U_DisplaySelectors.get_crt_curvature(state)
	_set_slider_value_silently(_crt_curvature_slider, curvature)
	_update_float_label(_crt_curvature_value, curvature, 1)

	var aberration := U_DisplaySelectors.get_crt_chromatic_aberration(state)
	_set_slider_value_silently(_crt_aberration_slider, aberration)
	_update_float_label(_crt_aberration_value, aberration, 4)

	_set_toggle_value_silently(_dither_toggle, U_DisplaySelectors.is_dither_enabled(state))
	var dither_intensity := U_DisplaySelectors.get_dither_intensity(state)
	_set_slider_value_silently(_dither_intensity_slider, dither_intensity)
	_update_percentage_label(_dither_intensity_value, dither_intensity)
	_select_option_value(_dither_pattern_option, _dither_pattern_values, U_DisplaySelectors.get_dither_pattern(state))

	_set_toggle_value_silently(_lut_toggle, U_DisplaySelectors.is_lut_enabled(state))
	var lut_resource := U_DisplaySelectors.get_lut_resource(state)
	var normalized_lut := _normalize_lut_resource(lut_resource)
	_ensure_lut_option_present(normalized_lut)
	_select_option_value(_lut_option, _lut_resource_values, normalized_lut)
	var lut_intensity := U_DisplaySelectors.get_lut_intensity(state)
	_set_slider_value_silently(_lut_intensity_slider, lut_intensity)
	_update_percentage_label(_lut_intensity_value, lut_intensity)

	var ui_scale := U_DisplaySelectors.get_ui_scale(state)
	_set_slider_value_silently(_ui_scale_slider, ui_scale)
	_update_scale_label(_ui_scale_value, ui_scale)

	_select_option_value(_color_blind_mode_option, _color_blind_mode_values, U_DisplaySelectors.get_color_blind_mode(state))
	_set_toggle_value_silently(_high_contrast_toggle, U_DisplaySelectors.is_high_contrast_enabled(state))
	_set_toggle_value_silently(_color_blind_shader_toggle, U_DisplaySelectors.is_color_blind_shader_enabled(state))

	_updating_from_state = false
	_has_local_edits = false

func _on_window_size_selected(index: int) -> void:
	if _updating_from_state:
		return
	if index < 0 or index >= _window_size_values.size():
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_window_mode_selected(index: int) -> void:
	if _updating_from_state:
		return
	if index < 0 or index >= _window_mode_values.size():
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_vsync_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_quality_preset_selected(index: int) -> void:
	if _updating_from_state:
		return
	if index < 0 or index >= _quality_preset_values.size():
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_film_grain_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_film_grain_intensity_changed(value: float) -> void:
	_update_percentage_label(_film_grain_intensity_value, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_crt_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_crt_scanline_changed(value: float) -> void:
	_update_percentage_label(_crt_scanline_value, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_crt_curvature_changed(value: float) -> void:
	_update_float_label(_crt_curvature_value, value, 1)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_crt_aberration_changed(value: float) -> void:
	_update_float_label(_crt_aberration_value, value, 4)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_dither_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_dither_intensity_changed(value: float) -> void:
	_update_percentage_label(_dither_intensity_value, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_dither_pattern_selected(index: int) -> void:
	if _updating_from_state:
		return
	if index < 0 or index >= _dither_pattern_values.size():
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_lut_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_lut_selected(index: int) -> void:
	if _updating_from_state:
		return
	if index < 0 or index >= _lut_resource_values.size():
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_lut_intensity_changed(value: float) -> void:
	_update_percentage_label(_lut_intensity_value, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_ui_scale_changed(value: float) -> void:
	_update_scale_label(_ui_scale_value, value)
	if _updating_from_state:
		return
	U_UISoundPlayer.play_slider_tick()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_color_blind_mode_selected(index: int) -> void:
	if _updating_from_state:
		return
	if index < 0 or index >= _color_blind_mode_values.size():
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_high_contrast_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_color_blind_shader_toggled(pressed: bool) -> void:
	if _updating_from_state:
		return
	U_UISoundPlayer.play_confirm()
	_has_local_edits = true
	_update_display_settings_preview_from_ui()

func _on_reset_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var defaults := _get_default_display_state()

	_updating_from_state = true
	_select_option_value(_window_size_option, _window_size_values, defaults.window_size_preset)
	_select_option_value(_window_mode_option, _window_mode_values, defaults.window_mode)
	_set_toggle_value_silently(_vsync_toggle, defaults.vsync_enabled)
	_select_option_value(_quality_preset_option, _quality_preset_values, defaults.quality_preset)

	_set_toggle_value_silently(_film_grain_toggle, defaults.film_grain_enabled)
	_set_slider_value_silently(_film_grain_intensity_slider, defaults.film_grain_intensity)
	_update_percentage_label(_film_grain_intensity_value, defaults.film_grain_intensity)

	_set_toggle_value_silently(_crt_toggle, defaults.crt_enabled)
	_set_slider_value_silently(_crt_scanline_slider, defaults.crt_scanline_intensity)
	_update_percentage_label(_crt_scanline_value, defaults.crt_scanline_intensity)
	_set_slider_value_silently(_crt_curvature_slider, defaults.crt_curvature)
	_update_float_label(_crt_curvature_value, defaults.crt_curvature, 1)
	_set_slider_value_silently(_crt_aberration_slider, defaults.crt_chromatic_aberration)
	_update_float_label(_crt_aberration_value, defaults.crt_chromatic_aberration, 4)

	_set_toggle_value_silently(_dither_toggle, defaults.dither_enabled)
	_set_slider_value_silently(_dither_intensity_slider, defaults.dither_intensity)
	_update_percentage_label(_dither_intensity_value, defaults.dither_intensity)
	_select_option_value(_dither_pattern_option, _dither_pattern_values, defaults.dither_pattern)

	_set_toggle_value_silently(_lut_toggle, defaults.lut_enabled)
	var normalized_default_lut := _normalize_lut_resource(defaults.lut_resource)
	_ensure_lut_option_present(normalized_default_lut)
	_select_option_value(_lut_option, _lut_resource_values, normalized_default_lut)
	_set_slider_value_silently(_lut_intensity_slider, defaults.lut_intensity)
	_update_percentage_label(_lut_intensity_value, defaults.lut_intensity)

	_set_slider_value_silently(_ui_scale_slider, defaults.ui_scale)
	_update_scale_label(_ui_scale_value, defaults.ui_scale)

	_select_option_value(_color_blind_mode_option, _color_blind_mode_values, defaults.color_blind_mode)
	_set_toggle_value_silently(_high_contrast_toggle, defaults.high_contrast_enabled)
	_set_toggle_value_silently(_color_blind_shader_toggle, defaults.color_blind_shader_enabled)

	_updating_from_state = false

	_has_local_edits = false
	_dispatch_display_settings(defaults)
	_clear_display_settings_preview()

func _on_cancel_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_has_local_edits = false
	_clear_display_settings_preview()
	_close_overlay()

func _on_apply_pressed() -> void:
	U_UISoundPlayer.play_confirm()
	var settings := _get_display_settings_from_ui()
	_has_local_edits = false
	_dispatch_display_settings(settings)
	_clear_display_settings_preview()
	_close_overlay()

func _close_overlay() -> void:
	if _state_store == null:
		return

	var nav_slice: Dictionary = _state_store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)

	if not overlay_stack.is_empty():
		_state_store.dispatch(U_NavigationActions.close_top_overlay())
	else:
		_state_store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_menu")))

func _update_display_settings_preview_from_ui() -> void:
	if _display_manager == null:
		_display_manager = U_DisplayUtils.get_display_manager()
	if _display_manager == null:
		return
	_display_manager.set_display_settings_preview(_get_display_settings_from_ui())

func _clear_display_settings_preview() -> void:
	if _display_manager == null:
		_display_manager = U_DisplayUtils.get_display_manager()
	if _display_manager == null:
		return
	_display_manager.clear_display_settings_preview()

func _dispatch_display_settings(settings: Variant) -> void:
	if _state_store == null:
		return
	var values: Dictionary = {}
	if settings is RS_DisplayInitialState:
		values = (settings as RS_DisplayInitialState).to_dictionary()
	elif settings is Dictionary:
		values = settings as Dictionary
	else:
		return

	_state_store.dispatch(U_DisplayActions.set_window_size_preset(String(values.get("window_size_preset", ""))))
	_state_store.dispatch(U_DisplayActions.set_window_mode(String(values.get("window_mode", ""))))
	_state_store.dispatch(U_DisplayActions.set_vsync_enabled(bool(values.get("vsync_enabled", true))))
	_state_store.dispatch(U_DisplayActions.set_quality_preset(String(values.get("quality_preset", ""))))
	_state_store.dispatch(U_DisplayActions.set_film_grain_enabled(bool(values.get("film_grain_enabled", false))))
	_state_store.dispatch(U_DisplayActions.set_film_grain_intensity(float(values.get("film_grain_intensity", 0.1))))
	_state_store.dispatch(U_DisplayActions.set_crt_enabled(bool(values.get("crt_enabled", false))))
	_state_store.dispatch(U_DisplayActions.set_crt_scanline_intensity(float(values.get("crt_scanline_intensity", 0.3))))
	_state_store.dispatch(U_DisplayActions.set_crt_curvature(float(values.get("crt_curvature", 2.0))))
	_state_store.dispatch(U_DisplayActions.set_crt_chromatic_aberration(float(values.get("crt_chromatic_aberration", 0.002))))
	_state_store.dispatch(U_DisplayActions.set_dither_enabled(bool(values.get("dither_enabled", false))))
	_state_store.dispatch(U_DisplayActions.set_dither_intensity(float(values.get("dither_intensity", 0.5))))
	_state_store.dispatch(U_DisplayActions.set_dither_pattern(String(values.get("dither_pattern", ""))))
	_state_store.dispatch(U_DisplayActions.set_lut_enabled(bool(values.get("lut_enabled", false))))
	_state_store.dispatch(U_DisplayActions.set_lut_resource(String(values.get("lut_resource", ""))))
	_state_store.dispatch(U_DisplayActions.set_lut_intensity(float(values.get("lut_intensity", 1.0))))
	_state_store.dispatch(U_DisplayActions.set_ui_scale(float(values.get("ui_scale", 1.0))))
	_state_store.dispatch(U_DisplayActions.set_color_blind_mode(String(values.get("color_blind_mode", ""))))
	_state_store.dispatch(U_DisplayActions.set_high_contrast_enabled(bool(values.get("high_contrast_enabled", false))))
	_state_store.dispatch(U_DisplayActions.set_color_blind_shader_enabled(bool(values.get("color_blind_shader_enabled", false))))

func _get_display_settings_from_ui() -> Dictionary:
	var defaults := _get_default_display_state()
	return {
		"window_size_preset": _get_selected_value(_window_size_option, _window_size_values, defaults.window_size_preset),
		"window_mode": _get_selected_value(_window_mode_option, _window_mode_values, defaults.window_mode),
		"vsync_enabled": _get_toggle_value(_vsync_toggle, defaults.vsync_enabled),
		"quality_preset": _get_selected_value(_quality_preset_option, _quality_preset_values, defaults.quality_preset),
		"film_grain_enabled": _get_toggle_value(_film_grain_toggle, defaults.film_grain_enabled),
		"film_grain_intensity": _get_slider_value(_film_grain_intensity_slider, defaults.film_grain_intensity),
		"crt_enabled": _get_toggle_value(_crt_toggle, defaults.crt_enabled),
		"crt_scanline_intensity": _get_slider_value(_crt_scanline_slider, defaults.crt_scanline_intensity),
		"crt_curvature": _get_slider_value(_crt_curvature_slider, defaults.crt_curvature),
		"crt_chromatic_aberration": _get_slider_value(_crt_aberration_slider, defaults.crt_chromatic_aberration),
		"dither_enabled": _get_toggle_value(_dither_toggle, defaults.dither_enabled),
		"dither_intensity": _get_slider_value(_dither_intensity_slider, defaults.dither_intensity),
		"dither_pattern": _get_selected_value(_dither_pattern_option, _dither_pattern_values, defaults.dither_pattern),
		"lut_enabled": _get_toggle_value(_lut_toggle, defaults.lut_enabled),
		"lut_resource": _get_selected_value(_lut_option, _lut_resource_values, _normalize_lut_resource(defaults.lut_resource)),
		"lut_intensity": _get_slider_value(_lut_intensity_slider, defaults.lut_intensity),
		"ui_scale": _get_slider_value(_ui_scale_slider, defaults.ui_scale),
		"color_blind_mode": _get_selected_value(_color_blind_mode_option, _color_blind_mode_values, defaults.color_blind_mode),
		"high_contrast_enabled": _get_toggle_value(_high_contrast_toggle, defaults.high_contrast_enabled),
		"color_blind_shader_enabled": _get_toggle_value(_color_blind_shader_toggle, defaults.color_blind_shader_enabled),
	}

func _get_selected_value(button: OptionButton, values: Array[String], fallback: String) -> String:
	if values.is_empty():
		return fallback
	if button == null:
		return fallback if not fallback.is_empty() else values[0]
	var idx := button.selected
	if idx < 0 or idx >= values.size():
		idx = 0
	return values[idx]

func _get_slider_value(slider: HSlider, fallback: float) -> float:
	if slider == null:
		return fallback
	return slider.value

func _get_toggle_value(toggle: BaseButton, fallback: bool) -> bool:
	if toggle == null:
		return fallback
	return toggle.button_pressed

func _set_slider_value_silently(slider: HSlider, value: float) -> void:
	if slider == null:
		return
	slider.set_block_signals(true)
	slider.value = value
	slider.set_block_signals(false)

func _set_toggle_value_silently(toggle: BaseButton, pressed: bool) -> void:
	if toggle == null:
		return
	toggle.set_block_signals(true)
	toggle.button_pressed = pressed
	toggle.set_block_signals(false)

func _select_option_value(button: OptionButton, values: Array[String], value: String) -> void:
	if button == null:
		return
	var idx := values.find(value)
	if idx < 0:
		idx = 0
	button.set_block_signals(true)
	button.select(idx)
	button.set_block_signals(false)

func _update_percentage_label(label: Label, value: float) -> void:
	if label == null:
		return
	label.text = "%d%%" % int(value * 100.0)

func _update_scale_label(label: Label, value: float) -> void:
	if label == null:
		return
	label.text = "%d%%" % int(value * 100.0)

func _update_float_label(label: Label, value: float, decimals: int) -> void:
	if label == null:
		return
	label.text = "%.*f" % [decimals, value]

func _ensure_lut_option_present(value: String) -> void:
	if value.is_empty():
		return
	if _lut_option == null:
		return
	if _lut_resource_values.has(value):
		return
	var label := _get_lut_label(value)
	_lut_option.add_item(label)
	_lut_resource_values.append(value)

func _get_lut_label(value: String) -> String:
	if value.is_empty():
		return "None"
	var resource := load(value)
	if resource is RS_LUT_DEFINITION:
		var definition := resource as RS_LUT_DEFINITION
		if not definition.display_name.is_empty():
			return definition.display_name
		return value.get_file().trim_suffix(".tres")
	if resource is Texture2D:
		return value.get_file().trim_suffix(".png")
	var file_name := value.get_file()
	if not file_name.is_empty():
		return file_name
	return value

func _normalize_lut_resource(value: String) -> String:
	if value.is_empty():
		return value
	if value.begins_with("uid://"):
		var resource := load(value)
		if resource != null:
			var path := resource.resource_path
			if path != "":
				return path
	return value

func _get_default_display_state() -> RS_DisplayInitialState:
	if DEFAULT_DISPLAY_INITIAL_STATE != null:
		var instance := DEFAULT_DISPLAY_INITIAL_STATE.duplicate(true)
		if instance is RS_DisplayInitialState:
			return instance as RS_DisplayInitialState
	return RS_DisplayInitialState.new()
