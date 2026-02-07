extends GutTest

# TDD: Test individual post-processing effect toggles (H1)
# State management supports per-effect toggles but applier ignores them

const U_DISPLAY_POST_PROCESS_APPLIER := preload("res://scripts/managers/helpers/display/u_display_post_process_applier.gd")
const U_POST_PROCESS_LAYER := preload("res://scripts/managers/helpers/u_post_process_layer.gd")

var _applier: RefCounted
var _mock_layer: MockPostProcessLayer

class MockPostProcessLayer extends RefCounted:
	var enabled_effects: Dictionary = {}

	func initialize(_root: Node) -> void:
		pass

	func set_effect_enabled(effect_name: StringName, enabled: bool) -> void:
		enabled_effects[effect_name] = enabled

	func set_effect_parameter(_effect_name: StringName, _param: StringName, _value: Variant) -> void:
		pass

	func is_effect_enabled(effect_name: StringName) -> bool:
		return enabled_effects.get(effect_name, false)

func before_each() -> void:
	_applier = U_DISPLAY_POST_PROCESS_APPLIER.new()
	var owner_node := Node.new()
	add_child_autofree(owner_node)
	_applier.initialize(owner_node)

	# Inject mock layer BEFORE any apply_settings() calls
	_mock_layer = MockPostProcessLayer.new()
	_applier.set("_post_process_layer", _mock_layer)

	# Stub _ensure_post_process_layer to prevent actual overlay setup in tests
	# We can't use partial doubles in GUT, so we rely on the fact that
	# _post_process_layer being non-null makes _ensure_post_process_layer() return true

func after_each() -> void:
	if _applier:
		_applier.set("_post_process_layer", null)
	_applier = null
	_mock_layer = null

# FAILING TEST: Film grain should respect its individual toggle
func test_film_grain_disabled_when_individual_toggle_off() -> void:
	var settings := {
		"post_processing_enabled": true,
		"film_grain_enabled": false,  # Individual toggle OFF
		"film_grain_intensity": 0.5,
	}

	_applier.apply_settings(settings)

	assert_false(
		_mock_layer.is_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_FILM_GRAIN),
		"Film grain should be disabled when film_grain_enabled=false"
	)

# FAILING TEST: Film grain should enable when individual toggle on
func test_film_grain_enabled_when_individual_toggle_on() -> void:
	var settings := {
		"post_processing_enabled": true,
		"film_grain_enabled": true,  # Individual toggle ON
		"film_grain_intensity": 0.5,
	}

	_applier.apply_settings(settings)

	assert_true(
		_mock_layer.is_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_FILM_GRAIN),
		"Film grain should be enabled when film_grain_enabled=true"
	)

# FAILING TEST: CRT should respect its individual toggle
func test_crt_disabled_when_individual_toggle_off() -> void:
	var settings := {
		"post_processing_enabled": true,
		"crt_enabled": false,  # Individual toggle OFF
		"crt_scanline_intensity": 0.3,
	}

	_applier.apply_settings(settings)

	assert_false(
		_mock_layer.is_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_CRT),
		"CRT should be disabled when crt_enabled=false"
	)

# FAILING TEST: CRT should enable when individual toggle on
func test_crt_enabled_when_individual_toggle_on() -> void:
	var settings := {
		"post_processing_enabled": true,
		"crt_enabled": true,  # Individual toggle ON
		"crt_scanline_intensity": 0.3,
	}

	_applier.apply_settings(settings)

	assert_true(
		_mock_layer.is_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_CRT),
		"CRT should be enabled when crt_enabled=true"
	)

# FAILING TEST: Dither should respect its individual toggle
func test_dither_disabled_when_individual_toggle_off() -> void:
	var settings := {
		"post_processing_enabled": true,
		"dither_enabled": false,  # Individual toggle OFF
		"dither_intensity": 0.5,
	}

	_applier.apply_settings(settings)

	assert_false(
		_mock_layer.is_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_DITHER),
		"Dither should be disabled when dither_enabled=false"
	)

# FAILING TEST: Dither should enable when individual toggle on
func test_dither_enabled_when_individual_toggle_on() -> void:
	var settings := {
		"post_processing_enabled": true,
		"dither_enabled": true,  # Individual toggle ON
		"dither_intensity": 0.5,
	}

	_applier.apply_settings(settings)

	assert_true(
		_mock_layer.is_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_DITHER),
		"Dither should be enabled when dither_enabled=true"
	)

# Edge case: Global toggle off should disable all effects regardless of individual toggles
func test_global_toggle_off_disables_all_effects() -> void:
	var settings := {
		"post_processing_enabled": false,  # Global toggle OFF
		"film_grain_enabled": true,
		"crt_enabled": true,
		"dither_enabled": true,
	}

	_applier.apply_settings(settings)

	assert_false(
		_mock_layer.is_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_FILM_GRAIN),
		"Film grain should be disabled when global toggle is off"
	)
	assert_false(
		_mock_layer.is_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_CRT),
		"CRT should be disabled when global toggle is off"
	)
	assert_false(
		_mock_layer.is_effect_enabled(U_POST_PROCESS_LAYER.EFFECT_DITHER),
		"Dither should be disabled when global toggle is off"
	)
