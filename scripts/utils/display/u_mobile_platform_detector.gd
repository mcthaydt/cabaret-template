extends RefCounted
class_name U_MobilePlatformDetector

## Detects mobile platform and provides mobile-specific rendering parameters.
##
## Centralizes mobile detection so callers don't need to repeat OS.has_feature()
## checks. Supports test overrides for deterministic unit testing.

## Default resolution scale factor on mobile (50% of native resolution).
const MOBILE_SCALE_FACTOR: float = 0.5

## Minimum viewport dimensions to avoid rendering artifacts on very small screens.
const MOBILE_MIN_VIEWPORT_WIDTH: int = 480
const MOBILE_MIN_VIEWPORT_HEIGHT: int = 320

## Test override: 1 = force mobile, 0 = force desktop, -1 = use OS detection.
static var _mobile_override: int = -1

## Test override: custom scale factor, < 0 = use MOBILE_SCALE_FACTOR.
static var _scale_override: float = -1.0

## Set to true during tests to enable override behavior.
static var _testing: bool = false

static func set_testing(enabled: bool) -> void:
	_testing = enabled

static func set_mobile_override(value: int) -> void:
	_mobile_override = value

static func set_scale_override(value: float) -> void:
	_scale_override = value

## Returns true if running on a mobile device (Android/iOS).
## In tests, uses the override value when set.
static func is_mobile() -> bool:
	if _testing:
		if _mobile_override >= 0:
			return _mobile_override == 1
	return OS.has_feature("mobile")

## Returns the viewport resolution scale factor.
## 1.0 on desktop, MOBILE_SCALE_FACTOR on mobile unless a custom override is set.
static func get_viewport_scale_factor() -> float:
	if _scale_override >= 0.0:
		return _scale_override
	if is_mobile():
		return MOBILE_SCALE_FACTOR
	return 1.0

## Scales a viewport size by the current scale factor, clamped to minimums.
static func scale_viewport_size(container_size: Vector2i, design_size: Vector2i = Vector2i.ZERO) -> Vector2i:
	var scale := get_viewport_scale_factor()
	var base: Vector2i = design_size if design_size.x > 0 else container_size
	var scaled := Vector2i(
		maxi(int(base.x * scale), MOBILE_MIN_VIEWPORT_WIDTH),
		maxi(int(base.y * scale), MOBILE_MIN_VIEWPORT_HEIGHT)
	)
	return scaled