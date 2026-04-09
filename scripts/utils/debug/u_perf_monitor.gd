extends Node
class_name U_PerfMonitor

## Frame-level FPS and render stats reporter for mobile performance diagnostics.
##
## Logs [PERF]-prefixed reports every N seconds with FPS, frame time,
## render stat deltas, viewport stats, and active shader pass count.
##
## Auto-enables on mobile. Zero-cost when disabled (early return in _process).

const LOG_PREFIX := "[PERF]"
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")

@export var enabled: bool = false
@export var report_interval_sec: float = 3.0

# FPS accumulation
var _fps_samples: int = 0
var _fps_total: float = 0.0
var _fps_min: float = INF
var _fps_max: float = 0.0

# Frame time accumulation (microseconds)
var _frame_time_samples: int = 0
var _frame_time_total_usec: int = 0
var _frame_time_min_usec: int = 9223372036854775807
var _frame_time_max_usec: int = 0

# Render stat baselines for delta reporting
var _last_object_count: int = -1
var _last_primitive_count: int = -1
var _last_draw_call_count: int = -1

# Timing
var _last_report_usec: int = 0
var _last_frame_usec: int = 0
var _is_mobile: bool = false


func _ready() -> void:
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()
	if _is_mobile:
		enabled = true
	set_process(enabled)
	_last_report_usec = Time.get_ticks_usec()
	_last_frame_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	if not enabled:
		return

	var now_usec: int = Time.get_ticks_usec()

	# Accumulate frame time
	if _last_frame_usec > 0:
		var frame_usec: int = now_usec - _last_frame_usec
		_frame_time_samples += 1
		_frame_time_total_usec += frame_usec
		if frame_usec < _frame_time_min_usec:
			_frame_time_min_usec = frame_usec
		if frame_usec > _frame_time_max_usec:
			_frame_time_max_usec = frame_usec
	_last_frame_usec = now_usec

	# Accumulate FPS
	var fps: float = Engine.get_frames_per_second()
	if fps > 0.0:
		_fps_samples += 1
		_fps_total += fps
		if fps < _fps_min:
			_fps_min = fps
		if fps > _fps_max:
			_fps_max = fps

	# Check flush
	var elapsed_usec: int = now_usec - _last_report_usec
	if elapsed_usec >= int(report_interval_sec * 1_000_000.0):
		_flush_report()


func set_enabled(v: bool) -> void:
	enabled = v
	set_process(v)
	if v:
		_last_frame_usec = Time.get_ticks_usec()
		_last_report_usec = Time.get_ticks_usec()


func _flush_report() -> void:
	var window_sec: float = report_interval_sec
	print("%s --- STATS (%.1fs window) ---" % [LOG_PREFIX, window_sec])

	# FPS
	if _fps_samples > 0:
		var avg_fps: float = _fps_total / float(_fps_samples)
		print("%s FPS: avg=%.1f min=%.1f max=%.1f samples=%d" % [
			LOG_PREFIX, avg_fps, _fps_min, _fps_max, _fps_samples
		])
	else:
		print("%s FPS: no samples" % LOG_PREFIX)

	# Frame time
	if _frame_time_samples > 0:
		var avg_ms: float = (float(_frame_time_total_usec) / float(_frame_time_samples)) / 1000.0
		var min_ms: float = float(_frame_time_min_usec) / 1000.0
		var max_ms: float = float(_frame_time_max_usec) / 1000.0
		print("%s Frame: avg=%.1fms min=%.1fms max=%.1fms" % [
			LOG_PREFIX, avg_ms, min_ms, max_ms
		])

	# Render stat deltas
	_flush_render_stats()

	# Viewport stats
	_flush_viewport_stats()

	# Shader pass count
	_flush_shader_pass_count()

	# Reset
	_fps_samples = 0
	_fps_total = 0.0
	_fps_min = INF
	_fps_max = 0.0
	_frame_time_samples = 0
	_frame_time_total_usec = 0
	_frame_time_min_usec = 9223372036854775807
	_frame_time_max_usec = 0
	_last_report_usec = Time.get_ticks_usec()


func _flush_render_stats() -> void:
	var object_count: int = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var primitive_count: int = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var draw_call_count: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

	if _last_object_count >= 0:
		print("%s Render: objects%+d prims%+d draws%+d" % [
			LOG_PREFIX,
			object_count - _last_object_count,
			primitive_count - _last_primitive_count,
			draw_call_count - _last_draw_call_count
		])

	_last_object_count = object_count
	_last_primitive_count = primitive_count
	_last_draw_call_count = draw_call_count


func _flush_viewport_stats() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var size: Vector2i = viewport.get_visible_rect().size
	var render_size: Vector2i = viewport.get_size()
	print("%s Viewport: size=%dx%d render=%dx%d" % [
		LOG_PREFIX, size.x, size.y, render_size.x, render_size.y
	])
	# Report the game SubViewport render size to verify mobile shrink is working
	var tree := get_tree()
	if tree != null and tree.root != null:
		var game_vp: Variant = tree.root.find_child("GameViewport", false, false)
		if game_vp is SubViewport:
			var game_size: Vector2i = game_vp.size
			print("%s GameVP: %dx%d" % [LOG_PREFIX, game_size.x, game_size.y])


func _flush_shader_pass_count() -> void:
	var combined_visible: bool = false
	var cinema_visible: bool = false

	# Check post-process overlay for active shader passes
	var overlay_node: Variant = null
	var tree := get_tree()
	if tree != null and tree.root != null:
		overlay_node = tree.root.find_child("PostProcessOverlay", false, false)
	if overlay_node is Node:
		for child in overlay_node.get_children():
			if child is CanvasLayer:
				var layer: CanvasLayer = child as CanvasLayer
				if layer.name == &"CombinedLayer" and layer.visible:
					combined_visible = true
				if layer.name == &"CinemaGradeLayer" and layer.visible:
					cinema_visible = true

	print("%s Shader passes: combined=%d cinema=%d" % [
		LOG_PREFIX, 1 if combined_visible else 0, 1 if cinema_visible else 0
	])