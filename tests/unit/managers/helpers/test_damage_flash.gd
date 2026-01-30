extends GutTest

const U_DamageFlash := preload("res://scripts/managers/helpers/u_damage_flash.gd")
const DAMAGE_FLASH_SCENE := preload("res://scenes/ui/overlays/ui_damage_flash_overlay.tscn")

var _flash_rect: ColorRect
var _damage_flash: U_DamageFlash


func before_each() -> void:
	_flash_rect = ColorRect.new()
	_flash_rect.modulate = Color(1, 1, 1, 0)
	add_child_autofree(_flash_rect)


func test_initialization_with_color_rect() -> void:
	_damage_flash = U_DamageFlash.new(_flash_rect, get_tree())

	assert_not_null(_damage_flash, "U_DamageFlash should initialize")


func test_flash_rect_color_alpha_is_1_0() -> void:
	var scene_instance := DAMAGE_FLASH_SCENE.instantiate()
	add_child_autofree(scene_instance)
	var flash_rect := scene_instance.get_node("FlashRect") as ColorRect
	assert_not_null(flash_rect, "FlashRect should exist in damage flash overlay scene")
	assert_almost_eq(flash_rect.color.a, 1.0, 0.001, "FlashRect color alpha should be 1.0")


func test_trigger_flash_sets_alpha_to_max_instantly() -> void:
	_damage_flash = U_DamageFlash.new(_flash_rect, get_tree())

	_damage_flash.trigger_flash()

	assert_almost_eq(_flash_rect.modulate.a, 0.3, 0.01, "Flash alpha should be set to MAX_ALPHA (0.3) instantly")


func test_fade_to_zero_over_duration() -> void:
	_damage_flash = U_DamageFlash.new(_flash_rect, get_tree())

	_damage_flash.trigger_flash()
	await wait_seconds(0.5)  # FADE_DURATION + buffer

	assert_almost_eq(_flash_rect.modulate.a, 0.0, 0.01, "Flash alpha should fade to 0.0 after FADE_DURATION")


func test_retrigger_kills_existing_tween() -> void:
	_damage_flash = U_DamageFlash.new(_flash_rect, get_tree())

	# First trigger
	_damage_flash.trigger_flash()
	await wait_seconds(0.2)  # Halfway through fade
	var alpha_mid_fade := _flash_rect.modulate.a

	# Second trigger (should kill first tween and restart)
	_damage_flash.trigger_flash()

	assert_almost_eq(_flash_rect.modulate.a, 0.3, 0.01, "Retrigger should reset alpha to MAX_ALPHA")
	assert_gt(_flash_rect.modulate.a, alpha_mid_fade, "Retrigger should increase alpha from mid-fade value")


func test_tween_has_pause_mode_process() -> void:
	_damage_flash = U_DamageFlash.new(_flash_rect, get_tree())

	_damage_flash.trigger_flash()

	assert_not_null(_damage_flash._tween, "Tween should be created on trigger")
	assert_eq(_damage_flash._tween_pause_mode, Tween.TWEEN_PAUSE_PROCESS, "Tween pause mode should be PROCESS")


func test_intensity_affects_max_alpha() -> void:
	_damage_flash = U_DamageFlash.new(_flash_rect, get_tree())

	_damage_flash.trigger_flash(0.5)  # 50% intensity

	assert_almost_eq(_flash_rect.modulate.a, 0.15, 0.01, "Flash alpha should be MAX_ALPHA * intensity (0.3 * 0.5 = 0.15)")


func test_zero_intensity_produces_no_flash() -> void:
	_damage_flash = U_DamageFlash.new(_flash_rect, get_tree())

	_damage_flash.trigger_flash(0.0)

	assert_eq(_flash_rect.modulate.a, 0.0, "Zero intensity should produce no flash")


func test_double_intensity_doubles_alpha() -> void:
	_damage_flash = U_DamageFlash.new(_flash_rect, get_tree())

	_damage_flash.trigger_flash(2.0)

	assert_almost_eq(_flash_rect.modulate.a, 0.6, 0.01, "Flash alpha should be MAX_ALPHA * intensity (0.3 * 2.0 = 0.6)")


func test_null_flash_rect_does_not_crash() -> void:
	_damage_flash = U_DamageFlash.new(null, get_tree())

	_damage_flash.trigger_flash()

	# Should not crash, just silently return
	assert_true(true, "Null flash_rect should not crash")


func test_null_scene_tree_does_not_crash() -> void:
	_damage_flash = U_DamageFlash.new(_flash_rect, null)

	_damage_flash.trigger_flash()

	# Should not crash, just silently return
	assert_true(true, "Null scene_tree should not crash")


func test_multiple_rapid_triggers_handle_gracefully() -> void:
	_damage_flash = U_DamageFlash.new(_flash_rect, get_tree())

	# Spam triggers
	_damage_flash.trigger_flash()
	_damage_flash.trigger_flash()
	_damage_flash.trigger_flash()

	# Should still be at max alpha (last trigger wins)
	assert_almost_eq(_flash_rect.modulate.a, 0.3, 0.01, "Multiple rapid triggers should result in max alpha")

	# Should still fade to zero
	await wait_seconds(0.5)
	assert_almost_eq(_flash_rect.modulate.a, 0.0, 0.01, "Multiple triggers should still fade to zero")
