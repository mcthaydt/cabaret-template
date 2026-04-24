extends Node
class_name U_PerfMonitor

## Frame-level FPS and render stats reporter for mobile performance diagnostics.
##
## Logs [PERF]-prefixed reports every N seconds with FPS, frame time,
## render stat deltas, viewport stats, and active shader pass count.
##
## Auto-enables on mobile. Zero-cost when disabled (early return in _process).

const LOG_PREFIX := "[PERF]"
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/core/utils/display/u_mobile_platform_detector.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

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
	var payload: Dictionary = _build_render_stats_payload()
	print("%s RenderAbs: objects=%d prims=%d draws=%d" % [
		LOG_PREFIX,
		int(payload.get("objects", 0)),
		int(payload.get("primitives", 0)),
		int(payload.get("draws", 0)),
	])
	if payload.has("delta_objects"):
		print("%s RenderDelta: objects%+d prims%+d draws%+d" % [
			LOG_PREFIX,
			int(payload.get("delta_objects", 0)),
			int(payload.get("delta_primitives", 0)),
			int(payload.get("delta_draws", 0)),
		])


func _flush_viewport_stats() -> void:
	var payload: Dictionary = _build_viewport_stats_payload()
	if payload.is_empty():
		return
	var root_visible_size: Vector2i = payload.get("root_visible_size", Vector2i.ZERO) as Vector2i
	var root_render_size: Vector2i = payload.get("root_render_size", Vector2i.ZERO) as Vector2i
	print("%s RootVP: visible=%dx%d render=%dx%d" % [
		LOG_PREFIX, root_visible_size.x, root_visible_size.y, root_render_size.x, root_render_size.y
	])

	if payload.has("game_visible_size") and payload.has("game_render_size"):
		var game_visible_size: Vector2i = payload.get("game_visible_size", Vector2i.ZERO) as Vector2i
		var game_render_size: Vector2i = payload.get("game_render_size", Vector2i.ZERO) as Vector2i
		print("%s GameVP: visible=%dx%d render=%dx%d" % [
			LOG_PREFIX, game_visible_size.x, game_visible_size.y, game_render_size.x, game_render_size.y
		])
	if payload.has("game_container_size") and payload.has("game_container_shrink"):
		var container_size: Vector2i = payload.get("game_container_size", Vector2i.ZERO) as Vector2i
		var container_shrink: int = int(payload.get("game_container_shrink", 1))
		print("%s GameVPContainer: size=%dx%d shrink=%d" % [
			LOG_PREFIX,
			container_size.x,
			container_size.y,
			container_shrink,
		])
	var mobile_scale: float = float(payload.get("mobile_scale", 1.0))
	print("%s MobileScale: %.2f" % [LOG_PREFIX, mobile_scale])


func _flush_shader_pass_count() -> void:
	var grain_dither_visible: bool = false
	var color_grading_visible: bool = false

	# Check post-process overlay for active shader passes
	var overlay_node: Variant = null
	var tree := get_tree()
	if tree != null and tree.root != null:
		overlay_node = tree.root.find_child("PostProcessOverlay", false, false)
	if overlay_node is Node:
		for child in overlay_node.get_children():
			if child is CanvasLayer:
				var layer: CanvasLayer = child as CanvasLayer
				if layer.name == &"GrainDitherLayer" and layer.visible:
					grain_dither_visible = true
				if layer.name == &"ColorGradingLayer" and layer.visible:
					color_grading_visible = true

	print("%s Shader passes: grain_dither=%d color_grading=%d" % [
		LOG_PREFIX, 1 if grain_dither_visible else 0, 1 if color_grading_visible else 0
	])

func _resolve_game_viewport() -> SubViewport:
	var from_service: Variant = U_SERVICE_LOCATOR.try_get_service(StringName("game_viewport"))
	if from_service is SubViewport:
		return from_service as SubViewport

	var tree := get_tree()
	if tree == null or tree.root == null:
		return null

	var from_tree: Variant = tree.root.find_child("GameViewport", true, false)
	if from_tree is SubViewport:
		return from_tree as SubViewport

	return null

func _build_render_stats_payload() -> Dictionary:
	var object_count: int = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var primitive_count: int = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var draw_call_count: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var payload := {
		"objects": object_count,
		"primitives": primitive_count,
		"draws": draw_call_count,
	}
	if _last_object_count >= 0:
		payload["delta_objects"] = object_count - _last_object_count
		payload["delta_primitives"] = primitive_count - _last_primitive_count
		payload["delta_draws"] = draw_call_count - _last_draw_call_count

	_last_object_count = object_count
	_last_primitive_count = primitive_count
	_last_draw_call_count = draw_call_count
	return payload

func _build_viewport_stats_payload() -> Dictionary:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return {}

	var root_viewport: Viewport = tree.root
	var payload := {
		"root_visible_size": root_viewport.get_visible_rect().size,
		"root_render_size": root_viewport.get_size(),
		"mobile_scale": U_MOBILE_PLATFORM_DETECTOR.get_viewport_scale_factor(),
	}

	var game_viewport: SubViewport = _resolve_game_viewport()
	if game_viewport != null and is_instance_valid(game_viewport):
		payload["game_visible_size"] = game_viewport.get_visible_rect().size
		payload["game_render_size"] = game_viewport.size
		var game_container: Node = game_viewport.get_parent()
		if game_container is SubViewportContainer:
			var container := game_container as SubViewportContainer
			payload["game_container_size"] = Vector2i(int(container.size.x), int(container.size.y))
			payload["game_container_shrink"] = container.stretch_shrink

	return payload
