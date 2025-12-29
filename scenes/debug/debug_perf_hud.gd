## Performance HUD overlay for Debug Manager
##
## Displays real-time FPS, frame time, memory, rendering, and ECS/State metrics.
## Toggled via F1 key through M_DebugManager.
class_name SC_DebugPerfHUD
extends CanvasLayer


## Label references
@onready var _fps_label: Label = %FPSLabel
@onready var _static_mem_label: Label = %StaticMemLabel
@onready var _dynamic_mem_label: Label = %DynamicMemLabel
@onready var _draw_calls_label: Label = %DrawCallsLabel
@onready var _object_count_label: Label = %ObjectCountLabel
@onready var _ecs_queries_label: Label = %ECSQueriesLabel
@onready var _state_dispatches_label: Label = %StateDispatchesLabel

## Frame graph control
@onready var _frame_graph: U_DebugFrameGraph = %FrameGraph

## Collapsible section containers
@onready var _memory_details: VBoxContainer = %MemoryDetails
@onready var _draw_details: VBoxContainer = %DrawDetails
@onready var _ecs_details: VBoxContainer = %ECSDetails

## Toggle buttons for sections
@onready var _memory_toggle: Button = %MemoryToggle
@onready var _draw_toggle: Button = %DrawToggle
@onready var _ecs_toggle: Button = %ECSToggle

# Note: No preloads needed - using global class names directly

## State Store reference (persistent, registered with ServiceLocator)
var _state_store: M_StateStore = null


func _ready() -> void:
	# Get state store (persistent in root.tscn, registered with ServiceLocator)
	_state_store = U_ServiceLocator.get_service(StringName("state_store")) as M_StateStore


func _process(_delta: float) -> void:
	_update_performance_metrics()


## Update all performance metrics
func _update_performance_metrics() -> void:
	var metrics := U_DebugPerfCollector.get_metrics()

	# Update FPS and frame time
	_fps_label.text = "FPS: %d (%.1fms)" % [metrics.fps, metrics.frame_time_ms]

	# Update frame graph
	_frame_graph.add_sample(metrics.frame_time_ms)

	# Update memory metrics
	_static_mem_label.text = "  Static: %.1f MB" % metrics.memory_static_mb
	_dynamic_mem_label.text = "  Peak: %.1f MB" % metrics.memory_static_max_mb

	# Update rendering metrics
	_draw_calls_label.text = "  Draw Calls: %d" % metrics.draw_calls
	_object_count_label.text = "  Objects: %d" % metrics.object_count

	# Update ECS metrics (if manager available in current scene)
	# Note: ECS manager is scene-specific, not registered with ServiceLocator
	var ecs_manager := get_tree().get_first_node_in_group("ecs_manager") as M_ECSManager
	if is_instance_valid(ecs_manager):
		var ecs_metrics: Array = ecs_manager.get_query_metrics()
		if ecs_metrics.size() > 0:
			# Aggregate metrics from all queries
			var total_calls := 0
			var total_cache_hits := 0
			var total_duration := 0.0
			for metric in ecs_metrics:
				if metric is Dictionary:
					total_calls += int(metric.get("total_calls", 0))
					total_cache_hits += int(metric.get("cache_hits", 0))
					total_duration += float(metric.get("last_duration", 0.0))
			var avg_duration_sec := total_duration / float(ecs_metrics.size()) if ecs_metrics.size() > 0 else 0.0
			var avg_duration_ms := avg_duration_sec * 1000.0  # Convert seconds to milliseconds
			var cache_hit_rate := (float(total_cache_hits) / float(total_calls) * 100.0) if total_calls > 0 else 0.0
			_ecs_queries_label.text = "  ECS: %d queries, %.0f%% cached" % [
				ecs_metrics.size(),
				cache_hit_rate
			]
		else:
			_ecs_queries_label.text = "  ECS Queries: 0"
	else:
		_ecs_queries_label.text = "  ECS Queries: No Manager"

	# Update State metrics (if store available)
	if is_instance_valid(_state_store):
		var state_metrics := _state_store.get_performance_metrics()
		if state_metrics.has("dispatch_count"):
			_state_dispatches_label.text = "  State: %d dispatches, %.3fms avg" % [
				state_metrics.dispatch_count,
				state_metrics.get("avg_dispatch_time_ms", 0.0)
			]
		else:
			_state_dispatches_label.text = "  State Dispatches: N/A"
	else:
		_state_dispatches_label.text = "  State Dispatches: No Store"


## Toggle memory details visibility
func _on_memory_toggle_toggled(toggled_on: bool) -> void:
	_memory_details.visible = toggled_on
	_memory_toggle.text = "▼" if toggled_on else "▶"


## Toggle draw details visibility
func _on_draw_toggle_toggled(toggled_on: bool) -> void:
	_draw_details.visible = toggled_on
	_draw_toggle.text = "▼" if toggled_on else "▶"


## Toggle ECS/State details visibility
func _on_ecs_toggle_toggled(toggled_on: bool) -> void:
	_ecs_details.visible = toggled_on
	_ecs_toggle.text = "▼" if toggled_on else "▶"
