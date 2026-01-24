extends GutTest

const RS_ScreenShakeTuning := preload("res://scripts/resources/ecs/rs_screen_shake_tuning.gd")

func test_calculate_damage_trauma_zero_returns_zero() -> void:
	var tuning := RS_ScreenShakeTuning.new()
	assert_almost_eq(tuning.calculate_damage_trauma(0.0), 0.0, 0.0001)

func test_calculate_damage_trauma_at_midpoint() -> void:
	var tuning := RS_ScreenShakeTuning.new()
	assert_almost_eq(tuning.calculate_damage_trauma(50.0), 0.45, 0.0001)

func test_calculate_damage_trauma_at_max() -> void:
	var tuning := RS_ScreenShakeTuning.new()
	assert_almost_eq(tuning.calculate_damage_trauma(100.0), 0.6, 0.0001)

func test_calculate_landing_trauma_below_threshold_returns_zero() -> void:
	var tuning := RS_ScreenShakeTuning.new()
	assert_almost_eq(tuning.calculate_landing_trauma(10.0), 0.0, 0.0001)

func test_calculate_landing_trauma_at_threshold() -> void:
	var tuning := RS_ScreenShakeTuning.new()
	assert_almost_eq(tuning.calculate_landing_trauma(15.0), 0.0, 0.0001)

func test_calculate_landing_trauma_at_max() -> void:
	var tuning := RS_ScreenShakeTuning.new()
	assert_almost_eq(tuning.calculate_landing_trauma(30.0), 0.4, 0.0001)

func test_death_trauma_field_accessible() -> void:
	var tuning := RS_ScreenShakeTuning.new()
	assert_almost_eq(tuning.death_trauma, 0.5, 0.0001)
