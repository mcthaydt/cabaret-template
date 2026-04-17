extends GutTest

const U_PERF_MONITOR := preload("res://scripts/utils/debug/u_perf_monitor.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")

var _monitor: U_PerfMonitor = null

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)
	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(-1.0)

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	U_MOBILE_PLATFORM_DETECTOR.set_testing(false)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(-1)
	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(-1.0)
	_monitor = null

func test_build_render_stats_payload_includes_abs_and_delta() -> void:
	_monitor = U_PERF_MONITOR.new()
	add_child_autofree(_monitor)

	var first: Dictionary = _monitor._build_render_stats_payload()
	assert_true(first.has("objects"), "First payload should include absolute object count")
	assert_true(first.has("primitives"), "First payload should include absolute primitive count")
	assert_true(first.has("draws"), "First payload should include absolute draw count")
	assert_false(first.has("delta_objects"), "First payload should not include deltas")

	var second: Dictionary = _monitor._build_render_stats_payload()
	assert_true(second.has("delta_objects"), "Second payload should include object delta")
	assert_true(second.has("delta_primitives"), "Second payload should include primitive delta")
	assert_true(second.has("delta_draws"), "Second payload should include draw delta")

func test_resolve_game_viewport_uses_service_locator_when_available() -> void:
	_monitor = U_PERF_MONITOR.new()
	add_child_autofree(_monitor)

	var game_viewport := SubViewport.new()
	game_viewport.name = "GameViewport"
	add_child_autofree(game_viewport)
	U_SERVICE_LOCATOR.register(StringName("game_viewport"), game_viewport)

	var resolved: SubViewport = _monitor._resolve_game_viewport()
	assert_eq(resolved, game_viewport, "Perf monitor should resolve GameViewport from ServiceLocator first")

func test_resolve_game_viewport_falls_back_to_recursive_tree_search() -> void:
	_monitor = U_PERF_MONITOR.new()
	add_child_autofree(_monitor)

	var parent := Node.new()
	parent.name = "NestedRoot"
	add_child_autofree(parent)
	var game_viewport := SubViewport.new()
	game_viewport.name = "GameViewport"
	parent.add_child(game_viewport)

	var resolved: SubViewport = _monitor._resolve_game_viewport()
	assert_eq(resolved, game_viewport, "Perf monitor should find GameViewport via recursive tree search")

func test_build_viewport_stats_payload_includes_root_game_viewport_and_mobile_scale() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(0.35)

	_monitor = U_PERF_MONITOR.new()
	add_child_autofree(_monitor)

	var container := SubViewportContainer.new()
	container.size = Vector2(960, 600)
	container.stretch_shrink = 3
	add_child_autofree(container)
	var game_viewport := SubViewport.new()
	game_viewport.name = "GameViewport"
	game_viewport.size = Vector2i(960, 600)
	container.add_child(game_viewport)
	U_SERVICE_LOCATOR.register(StringName("game_viewport"), game_viewport)

	var payload: Dictionary = _monitor._build_viewport_stats_payload()
	assert_true(payload.has("root_visible_size"), "Payload should include root viewport visible size")
	assert_true(payload.has("root_render_size"), "Payload should include root viewport render size")
	assert_true(payload.has("game_visible_size"), "Payload should include game viewport visible size")
	assert_true(payload.has("game_render_size"), "Payload should include game viewport render size")
	assert_true(payload.has("game_container_shrink"), "Payload should include game viewport container shrink")
	assert_almost_eq(float(payload.get("mobile_scale", 1.0)), 0.35, 0.001, "Payload should report active mobile scale")
