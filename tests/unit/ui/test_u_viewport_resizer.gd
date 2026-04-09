extends GutTest

## Tests for U_ViewportResizer mobile resolution scaling behavior.

const U_VIEWPORT_RESIZER := preload("res://scripts/ui/utils/u_viewport_resizer.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")

var _container: SubViewportContainer
var _viewport: SubViewport

func before_each() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_testing(true)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)
	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(-1.0)

func after_each() -> void:
	if _container != null and is_instance_valid(_container):
		_container.queue_free()
	_container = null
	_viewport = null
	U_MOBILE_PLATFORM_DETECTOR.set_testing(false)
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(-1)
	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(-1.0)

func _build_viewport_resizer(with_stretch: bool, container_size: Vector2i = Vector2i(960, 600)) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.name = "GameViewportContainer"
	# Don't set anchors_preset — keep at default so size stays fixed in tests
	container.stretch = with_stretch
	container.size = container_size
	container.set_script(U_VIEWPORT_RESIZER)

	_viewport = SubViewport.new()
	_viewport.name = "GameViewport"
	_viewport.size = Vector2i(960, 600)
	container.add_child(_viewport)

	return container

# --- Desktop (no scaling) ---

func test_desktop_stretch_false_sets_viewport_to_container_size() -> void:
	_container = _build_viewport_resizer(false)
	add_child(_container)
	await get_tree().process_frame

	var expected_size := Vector2i(int(_container.size.x), int(_container.size.y))
	assert_eq(_viewport.size, expected_size,
		"Viewport size should match container size on desktop with stretch=false")

func test_desktop_stretch_true_no_shrink() -> void:
	_container = _build_viewport_resizer(true)
	add_child(_container)
	await get_tree().process_frame

	assert_eq(_container.stretch_shrink, 1,
		"stretch_shrink should be 1 on desktop (no reduction)")

# --- Mobile scaling (stretch = false) ---

func test_mobile_stretch_false_scales_viewport() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	_container = _build_viewport_resizer(false, Vector2i(960, 600))
	add_child(_container)
	await get_tree().process_frame

	var expected := U_MOBILE_PLATFORM_DETECTOR.scale_viewport_size(Vector2i(960, 600))
	assert_eq(_viewport.size, expected,
		"Viewport size should be scaled on mobile with stretch=false")

# --- Mobile scaling (stretch = true) — uses stretch_shrink ---

func test_mobile_stretch_true_sets_shrink() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	_container = _build_viewport_resizer(true)
	add_child(_container)
	await get_tree().process_frame

	assert_eq(_container.stretch_shrink, 3,
		"stretch_shrink should be 3 on mobile with 0.35 scale factor")

func test_mobile_stretch_true_minimum_shrink_is_2() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(0.75)
	_container = _build_viewport_resizer(true)
	add_child(_container)
	await get_tree().process_frame

	assert_eq(_container.stretch_shrink, 2,
		"stretch_shrink should clamp to minimum 2 when mobile scale < 1.0")

func test_desktop_stretch_true_shrink_is_1() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(0)
	_container = _build_viewport_resizer(true)
	add_child(_container)
	await get_tree().process_frame

	assert_eq(_container.stretch_shrink, 1,
		"stretch_shrink should be 1 on desktop (full resolution)")

# --- Resize responsiveness ---

func test_mobile_stretch_true_updates_on_container_resize() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	_container = _build_viewport_resizer(true, Vector2i(960, 600))
	add_child(_container)
	await get_tree().process_frame

	assert_eq(_container.stretch_shrink, 3,
		"stretch_shrink should be 3 initially")

	# Trigger resize
	_container._on_resized()
	assert_eq(_container.stretch_shrink, 3,
		"stretch_shrink should remain 3 after resize on mobile")

func test_mobile_stretch_true_runtime_scale_refresh_updates_shrink_to_floor() -> void:
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(0.50)
	_container = _build_viewport_resizer(true, Vector2i(960, 600))
	add_child(_container)
	await get_tree().process_frame

	assert_eq(_container.stretch_shrink, 2,
		"stretch_shrink should start at 2 for scale=0.50")

	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(0.35)
	_container.request_scale_refresh()
	assert_eq(_container.stretch_shrink, 3,
		"stretch_shrink should refresh to 3 for runtime scale floor=0.35")

# --- Mobile DPI scaling (high-DPI container) ---

func test_mobile_stretch_true_accounts_for_dpi_scale() -> void:
	# Simulate a high-DPI mobile device where the container expands to
	# physical screen size (2249x945) while design resolution is 960x600.
	# dpi_scale = 2249/960 ≈ 2.34, stretch_shrink = round(2.34/0.35) = 7
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	_container = _build_viewport_resizer(true, Vector2i(2249, 945))
	add_child(_container)
	await get_tree().process_frame

	assert_eq(_container.stretch_shrink, 7,
		"stretch_shrink should account for DPI scaling on high-DPI mobile")

func test_mobile_stretch_true_dpi_scale_with_custom_scale() -> void:
	# Same high-DPI device but with 0.75 scale override.
	# dpi_scale = 2249/960 ≈ 2.34, stretch_shrink = round(2.34/0.75) = round(3.12) = 3
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	U_MOBILE_PLATFORM_DETECTOR.set_scale_override(0.75)
	_container = _build_viewport_resizer(true, Vector2i(2249, 945))
	add_child(_container)
	await get_tree().process_frame

	assert_eq(_container.stretch_shrink, 3,
		"stretch_shrink should account for DPI scale with custom mobile scale")

func test_mobile_stretch_true_low_dpi_device() -> void:
	# Simulate a 1080p phone: container=1440x900, design=960x600
	# dpi_scale = 1440/960 = 1.5, stretch_shrink = round(1.5/0.35) = 4
	U_MOBILE_PLATFORM_DETECTOR.set_mobile_override(1)
	_container = _build_viewport_resizer(true, Vector2i(1440, 900))
	add_child(_container)
	await get_tree().process_frame

	assert_eq(_container.stretch_shrink, 4,
		"stretch_shrink should scale correctly on 1080p-class mobile")
