## Frame time graph visualization for Debug Manager
##
## Displays a rolling graph of the last 60 frame times with color-coded performance indicators.
## Green target line at 16.67ms (60 FPS), yellow threshold at 33.33ms (30 FPS), red at 50ms (20 FPS).
class_name U_DebugFrameGraph
extends Control


## Maximum number of frame samples to display
const MAX_SAMPLES := 60

## Target frame time for 60 FPS (milliseconds)
const TARGET_60FPS := 16.67

## Warning threshold for 30 FPS (milliseconds)
const WARNING_30FPS := 33.33

## Critical threshold for 20 FPS (milliseconds)
const CRITICAL_20FPS := 50.0

## Maximum frame time to display on graph (milliseconds)
const MAX_DISPLAY_TIME := 60.0

## Circular buffer of frame times
var _frame_times: Array[float] = []

## Current write position in circular buffer
var _write_index := 0

## Number of samples currently stored
var _sample_count := 0


func _ready() -> void:
	# Initialize buffer with zeros
	_frame_times.resize(MAX_SAMPLES)
	_frame_times.fill(0.0)

	# Set minimum size for graph
	custom_minimum_size = Vector2(200, 60)


## Add a new frame time sample to the graph
func add_sample(frame_time_ms: float) -> void:
	_frame_times[_write_index] = frame_time_ms
	_write_index = (_write_index + 1) % MAX_SAMPLES
	_sample_count = mini(_sample_count + 1, MAX_SAMPLES)
	queue_redraw()


## Draw the frame graph
func _draw() -> void:
	if _sample_count == 0:
		return

	var graph_size := size
	var graph_height := graph_size.y
	var graph_width := graph_size.x

	# Draw background
	draw_rect(Rect2(Vector2.ZERO, graph_size), Color(0.1, 0.1, 0.1, 0.8))

	# Draw threshold lines
	_draw_threshold_line(TARGET_60FPS, Color.GREEN, graph_height)
	_draw_threshold_line(WARNING_30FPS, Color.YELLOW, graph_height)
	_draw_threshold_line(CRITICAL_20FPS, Color.RED, graph_height)

	# Draw frame time graph
	_draw_frame_samples(graph_width, graph_height)


## Draw a horizontal threshold line at the given frame time
func _draw_threshold_line(frame_time_ms: float, color: Color, graph_height: float) -> void:
	var y_pos := graph_height - (frame_time_ms / MAX_DISPLAY_TIME) * graph_height
	y_pos = clampf(y_pos, 0.0, graph_height)
	draw_line(Vector2(0, y_pos), Vector2(size.x, y_pos), color * Color(1, 1, 1, 0.3), 1.0)


## Draw the frame time samples as a line graph
func _draw_frame_samples(graph_width: float, graph_height: float) -> void:
	var sample_width := graph_width / float(MAX_SAMPLES)
	var prev_point := Vector2.ZERO

	for i in range(_sample_count):
		# Read from circular buffer in correct order (oldest to newest)
		# If buffer not full: start from 0
		# If buffer full: start from _write_index (oldest, about to be overwritten)
		var oldest_index := 0 if _sample_count < MAX_SAMPLES else _write_index
		var read_index := (oldest_index + i) % MAX_SAMPLES
		var frame_time := _frame_times[read_index]

		# Calculate position
		var x_pos := i * sample_width
		var y_pos := graph_height - (frame_time / MAX_DISPLAY_TIME) * graph_height
		y_pos = clampf(y_pos, 0.0, graph_height)

		var current_point := Vector2(x_pos, y_pos)

		# Draw line from previous point
		if i > 0:
			var color := _get_color_for_frame_time(frame_time)
			draw_line(prev_point, current_point, color, 2.0)

		prev_point = current_point


## Get color for frame time based on performance thresholds
func _get_color_for_frame_time(frame_time_ms: float) -> Color:
	if frame_time_ms > CRITICAL_20FPS:
		return Color.RED
	elif frame_time_ms > WARNING_30FPS:
		return Color.YELLOW
	else:
		return Color.GREEN
