extends Node
class_name U_PerfMonitor

## Lightweight performance monitor for mobile diagnostics.
##
## Logs FPS, frame time, GPU stats, and render pipeline metrics at ~1Hz on mobile.
## Also logs ECS system profiling data if available.
## Zero-cost on desktop (exits _process immediately).
## Attach as a child of any node in the scene tree.
##
## Debug toggle: 5 rapid taps (within 2 seconds) cycles shader bypass modes:
##   Mode 0: All shaders ON (default)
##   Mode 1: Cinema grade OFF (combined post-process still on)
##   Mode 2: All shaders OFF (both cinema grade and post-process disabled)
##   Mode 3: All shaders ON (back to default)

const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")

const DEBUG_TAP_COUNT: int = 5
const DEBUG_TAP_WINDOW_SEC: float = 2.0

var _is_mobile: bool = false
var _frame_counter: int = 0
var _log_interval_frames: int = 60  # ~1Hz at 60fps, ~2Hz at 30fps
var _ecs_manager: Node = null  # M_ECSManager

# Previous-frame render stats for delta computation
var _prev_draw_calls: int = -1
var _prev_primitives: int = -1
var _prev_objects: int = -1

# Debug shader bypass state
var _debug_tap_times: Array[float] = []
var _shader_bypass_mode: int = 0  # 0=all on, 1=cinema off, 2=all off


func _ready() -> void:
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()
	if not _is_mobile:
		set_process(false)
		return
	# Try to find ECS manager for system profiling data
	_ecs_manager = get_node_or_null("/root/Managers/M_ECSManager")


func _process(_delta: float) -> void:
	if not _is_mobile:
		return

	_frame_counter += 1
	if _frame_counter < _log_interval_frames:
		return
	_frame_counter = 0

	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var frame_time_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_time_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objects: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))

	print("[PERF] fps=%.1f frame=%.2fms physics=%.2fms draws=%d prims=%d objs=%d" % [
		fps, frame_time_ms, physics_time_ms, draw_calls, primitives, objects
	])

	# Log render stat deltas (how much draw calls/prims changed between samples)
	if _prev_draw_calls >= 0:
		var draw_delta: int = draw_calls - _prev_draw_calls
		var prim_delta: int = primitives - _prev_primitives
		var obj_delta: int = objects - _prev_objects
		print("[PERF] render_delta: draws%+d prims%+d objs%+d" % [
			draw_delta, prim_delta, obj_delta
		])
	_prev_draw_calls = draw_calls
	_prev_primitives = primitives
	_prev_objects = objects

	# Log viewport and shader pass info
	_log_viewport_render_stats()

	# Log ECS system profiling data if available
	if _ecs_manager != null and is_instance_valid(_ecs_manager) and _ecs_manager.has_method("get_system_profiling_data"):
		var profiling_data: Array = _ecs_manager.call("get_system_profiling_data")
		for entry in profiling_data:
			if entry is Dictionary:
				var sys_name: String = str(entry.get("system_name", "?"))
				var avg_usec: float = float(entry.get("avg_usec", 0.0))
				var max_usec: float = float(entry.get("max_usec", 0.0))
				var frame_count: int = int(entry.get("frame_count", 0))
				if avg_usec > 50.0:  # Only log systems > 0.05ms avg
					print("[PERF]   %s: avg=%.3fms max=%.3fms frames=%d" % [
						sys_name, avg_usec / 1000.0, max_usec / 1000.0, frame_count
					])


func _log_viewport_render_stats() -> void:
	# Log viewport resolution and any CanvasLayer info for diagnosing
	# whether shader passes are rendering at full or reduced resolution
	var main_vp := get_viewport()
	if main_vp == null:
		return
	var vp_size: Vector2i = main_vp.get_visible_rect().size
	var render_target_size: Vector2i = Vector2i(main_vp.get_size())
	# Check if there's a scaling transform on the viewport
	var stretch_transform := main_vp.get_final_transform()
	var scale_x: float = stretch_transform.x.x
	var scale_y: float = stretch_transform.y.y
	print("[PERF] viewport: size=%dx%d render=%dx%d scale=%.2fx%.2f" % [
		vp_size.x, vp_size.y, render_target_size.x, render_target_size.y, scale_x, scale_y
	])

	# Log all visible CanvasLayers with shader materials (fullscreen passes)
	var root := get_tree().root if get_tree() != null else null
	if root == null:
		return
	var shader_passes: Array = []
	_find_shader_canvas_layers(root, shader_passes)
	print("[PERF] fullscreen_shader_passes=%d" % shader_passes.size())
	for pass_info in shader_passes:
		print("[PERF]   %s" % pass_info)


func _find_shader_canvas_layers(node: Node, out_passes: Array) -> void:
	if node is CanvasLayer:
		for child in node.get_children():
			if child is ColorRect:
				var rect := child as ColorRect
				if rect.material is ShaderMaterial and rect.visible:
					var shader_name: String = ""
					var shader_mat := rect.material as ShaderMaterial
					if shader_mat.shader != null:
						shader_name = shader_mat.shader.resource_path.get_file().get_basename()
					out_passes.append("shader_pass: layer=%s shader=%s" % [
						node.name, shader_name
					])
	for child in node.get_children():
		_find_shader_canvas_layers(child, out_passes)


## Handle screen taps for debug shader bypass toggle.
## 5 taps within 2 seconds cycles through bypass modes.
func _input(event: InputEvent) -> void:
	if not _is_mobile:
		return
	if not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if not touch.pressed:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	_debug_tap_times.append(now)
	# Remove taps outside the window
	while _debug_tap_times.size() > 0 and (now - _debug_tap_times[0]) > DEBUG_TAP_WINDOW_SEC:
		_debug_tap_times.pop_front()
	if _debug_tap_times.size() >= DEBUG_TAP_COUNT:
		_debug_tap_times.clear()
		_cycle_shader_bypass()


func _cycle_shader_bypass() -> void:
	_shader_bypass_mode = (_shader_bypass_mode + 1) % 3
	var display_manager := _get_display_manager()
	if display_manager == null:
		return

	match _shader_bypass_mode:
		0:  # All shaders ON
			display_manager.call("_set_all_shaders_debug", true)
			print("[PERF] === SHADER BYPASS: ALL ON (mode 0) ===")
		1:  # Cinema grade OFF
			display_manager.call("_set_all_shaders_debug", true)  # restore first
			display_manager.call("_toggle_cinema_grade_debug")
			print("[PERF] === SHADER BYPASS: CINEMA GRADE OFF (mode 1) ===")
		2:  # All shaders OFF
			display_manager.call("_set_all_shaders_debug", false)
			print("[PERF] === SHADER BYPASS: ALL OFF (mode 2) ===")


func _get_display_manager() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.find_child("M_DisplayManager", true, false)