## Performance metrics collector for Debug Manager
##
## Collects FPS, frame time, memory, and rendering metrics from Godot's Performance singleton.
## Used by SC_DebugPerfHUD to display real-time performance data.
class_name U_DebugPerfCollector
extends RefCounted


## Collects current performance metrics from the engine
##
## Returns Dictionary with keys:
## - fps: Current frames per second
## - frame_time_ms: Frame processing time in milliseconds
## - memory_static_mb: Static memory usage in megabytes
## - memory_static_max_mb: Peak static memory usage in megabytes
## - draw_calls: Total draw calls in current frame
## - object_count: Total object count in scene
static func get_metrics() -> Dictionary:
	return {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"frame_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"memory_static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"memory_static_max_mb": Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT)
	}
