extends CanvasLayer
class_name U_PerfShaderBypass

## Mobile debug utility: detects 5 rapid taps and cycles through shader bypass modes.
##
## Cycles: ALL_ON → CINEMA_OFF → POST_PROCESS_OFF → ALL_OFF → FADE_OFF → ALL_ON
## Prints [PERF] log on each toggle. Watch FPS before/after each toggle to
## identify which shader pass causes the biggest drop.

const LOG_PREFIX := "[PERF]"
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")
const U_PERF_FADE_BYPASS := preload("res://scripts/utils/debug/u_perf_fade_bypass.gd")

const RAPID_TAP_COUNT := 5
const RAPID_TAP_MAX_INTERVAL_SEC := 0.6
const SHADER_BYPASS_MODES := [
	"ALL_ON",
	"CINEMA_OFF",
	"POST_PROCESS_OFF",
	"ALL_OFF",
	"FADE_OFF",
]

var _is_mobile: bool = false
var _enabled: bool = false
var _tap_times: Array[float] = []
var _current_mode_index: int = 0

# Saved state for restoration
var _was_combined_visible: bool = true
var _was_cinema_visible: bool = true


func _ready() -> void:
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()
	if not _is_mobile:
		set_process_input(false)
		return
	_enabled = true
	layer = 999  # Above everything to catch taps


func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventScreenTouch and event.pressed:
		_register_tap()


func _register_tap() -> void:
	var now: float = Time.get_ticks_usec() / 1_000_000.0
	_tap_times.append(now)
	# Prune old taps beyond the count we need
	while _tap_times.size() > RAPID_TAP_COUNT:
		_tap_times.pop_front()
	# Check if we have RAPID_TAP_COUNT taps within the interval
	if _tap_times.size() >= RAPID_TAP_COUNT:
		var oldest: float = _tap_times[0]
		if now - oldest <= RAPID_TAP_MAX_INTERVAL_SEC:
			_cycle_bypass_mode()
			_tap_times.clear()


func _cycle_bypass_mode() -> void:
	_current_mode_index = (_current_mode_index + 1) % SHADER_BYPASS_MODES.size()
	var mode: String = SHADER_BYPASS_MODES[_current_mode_index]
	print("%s === SHADER BYPASS: %s ===" % [LOG_PREFIX, mode])

	match mode:
		"ALL_ON":
			_restore_all()
		"CINEMA_OFF":
			_disable_cinema_only()
		"POST_PROCESS_OFF":
			_disable_post_process_only()
		"ALL_OFF":
			_disable_all()
		"FADE_OFF":
			_disable_fade_only()


func _get_display_manager() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	var dm: Variant = tree.root.find_child("DisplayManager", false, false)
	if dm != null:
		return dm as Node
	# Fallback: try service locator
	var U_SERVICE_LOCATOR := load("res://scripts/core/u_service_locator.gd")
	if U_SERVICE_LOCATOR != null:
		var service: Variant = U_SERVICE_LOCATOR.try_get_service(StringName("display_manager"))
		if service is Node:
			return service
	return null


func _get_color_grading_applier() -> RefCounted:
	var dm := _get_display_manager()
	if dm == null:
		return null
	var applier: Variant = dm.get("_color_grading_applier")
	if applier is RefCounted:
		return applier as RefCounted
	return null


func _get_post_process_applier() -> RefCounted:
	var dm := _get_display_manager()
	if dm == null:
		return null
	var applier: Variant = dm.get("_post_process_applier")
	if applier is RefCounted:
		return applier as RefCounted
	return null


func _restore_all() -> void:
	var pp_applier := _get_post_process_applier()
	if pp_applier != null and pp_applier.has_method("debug_restore_combined_visibility"):
		pp_applier.call("debug_restore_combined_visibility", _was_combined_visible)
	var cg_applier := _get_color_grading_applier()
	if cg_applier != null and cg_applier.has_method("debug_restore_visibility"):
		cg_applier.call("debug_restore_visibility", _was_cinema_visible)
	U_PERF_FADE_BYPASS.set_enabled(false)


func _disable_cinema_only() -> void:
	# Restore post-process first
	var pp_applier := _get_post_process_applier()
	if pp_applier != null and pp_applier.has_method("debug_restore_combined_visibility"):
		pp_applier.call("debug_restore_combined_visibility", _was_combined_visible)
	# Disable cinema grade
	var cg_applier := _get_color_grading_applier()
	if cg_applier != null and cg_applier.has_method("debug_force_disable"):
		# Save current visibility before disabling
		_was_cinema_visible = true
		cg_applier.call("debug_force_disable")
	U_PERF_FADE_BYPASS.set_enabled(false)


func _disable_post_process_only() -> void:
	# Restore cinema grade first
	var cg_applier := _get_color_grading_applier()
	if cg_applier != null and cg_applier.has_method("debug_restore_visibility"):
		cg_applier.call("debug_restore_visibility", _was_cinema_visible)
	# Disable post-process combined rect
	var pp_applier := _get_post_process_applier()
	if pp_applier != null and pp_applier.has_method("debug_force_disable_combined"):
		_was_combined_visible = true
		pp_applier.call("debug_force_disable_combined")
	U_PERF_FADE_BYPASS.set_enabled(false)


func _disable_all() -> void:
	var pp_applier := _get_post_process_applier()
	if pp_applier != null and pp_applier.has_method("debug_force_disable_combined"):
		pp_applier.call("debug_force_disable_combined")
	var cg_applier := _get_color_grading_applier()
	if cg_applier != null and cg_applier.has_method("debug_force_disable"):
		cg_applier.call("debug_force_disable")
	U_PERF_FADE_BYPASS.set_enabled(false)

func _disable_fade_only() -> void:
	# Fade isolation A/B: keep screen-space post-processing active, disable room/region fades.
	var pp_applier := _get_post_process_applier()
	if pp_applier != null and pp_applier.has_method("debug_restore_combined_visibility"):
		pp_applier.call("debug_restore_combined_visibility", _was_combined_visible)
	var cg_applier := _get_color_grading_applier()
	if cg_applier != null and cg_applier.has_method("debug_restore_visibility"):
		cg_applier.call("debug_restore_visibility", _was_cinema_visible)
	U_PERF_FADE_BYPASS.set_enabled(true)
