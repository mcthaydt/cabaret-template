@icon("res://resources/editor_icons/manager.svg")
extends Node
class_name M_DebugManager

## Debug Manager - Orchestrates all development-time debugging tools
##
## Responsibilities:
## - F-key input handling (F1=Perf HUD, F2=ECS Overlay, F3=State Overlay, F4=Toggle Menu)
## - Overlay lifecycle (instantiate on first toggle, show/hide on subsequent toggles)
## - Telemetry logging coordination (subscribe to events, auto-save session on exit)
## - Time scale control via Engine.time_scale
## - Debug build gating (strip self in release builds)
##
## Discovery: Add to "debug_manager" group, discoverable via get_tree().get_nodes_in_group()
##
## Note: This manager is automatically removed in release builds via OS.is_debug_build() check

# Preload overlay scenes (lazy instantiation)
const SC_DEBUG_PERF_HUD := preload("res://scenes/debug/debug_perf_hud.tscn")
const SC_DEBUG_ECS_OVERLAY := preload("res://scenes/debug/debug_ecs_overlay.tscn")
const SC_DEBUG_STATE_OVERLAY := preload("res://scenes/debug/debug_state_overlay.tscn")
const SC_DEBUG_TOGGLE_MENU := preload("res://scenes/debug/debug_toggle_menu.tscn")

# Helper utilities
const U_DEBUG_TELEMETRY := preload("res://scripts/managers/helpers/u_debug_telemetry.gd")

# State imports
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_DEBUG_SELECTORS := preload("res://scripts/state/selectors/u_debug_selectors.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")

# ECS Event Bus for telemetry subscriptions
const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")

# Overlay instances (lazy loaded)
var _overlay_instances: Dictionary = {
	StringName("perf_hud"): null,
	StringName("ecs_overlay"): null,
	StringName("state_overlay"): null,
	StringName("toggle_menu"): null,
}

# Overlay scene mapping
var _overlay_scenes: Dictionary = {
	StringName("perf_hud"): SC_DEBUG_PERF_HUD,
	StringName("ecs_overlay"): SC_DEBUG_ECS_OVERLAY,
	StringName("state_overlay"): SC_DEBUG_STATE_OVERLAY,
	StringName("toggle_menu"): SC_DEBUG_TOGGLE_MENU,
}

# Prevent race conditions during instantiation
var _instantiating: Dictionary = {}

# State store reference
var _store: M_STATE_STORE = null


func _ready() -> void:
	# CRITICAL: Strip debug manager from release builds
	if not OS.is_debug_build():
		queue_free()
		return

	# Add to discovery group
	add_to_group("debug_manager")

	# Initialize telemetry system
	U_DEBUG_TELEMETRY.log_info(StringName("system"), "Debug Manager initialized")

	# Get state store reference
	await get_tree().process_frame
	_store = U_STATE_UTILS.get_store(self)

	# Subscribe to debug state changes
	if _store:
		_store.slice_updated.connect(_on_slice_updated)

	# Subscribe to events for telemetry logging
	_subscribe_to_telemetry_events()

	# Cleanup old log files (auto-delete >7 days)
	_cleanup_old_logs()


func _exit_tree() -> void:
	# Auto-save session log on exit
	if OS.is_debug_build():
		_save_session_log()


func _input(event: InputEvent) -> void:
	# Handle F-key toggles
	if event.is_action_pressed("debug_toggle_perf"):
		toggle_overlay(StringName("perf_hud"))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_toggle_ecs"):
		toggle_overlay(StringName("ecs_overlay"))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_debug_overlay"):
		# F3 - migrated from M_StateStore
		toggle_overlay(StringName("state_overlay"))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_toggle_menu"):
		toggle_overlay(StringName("toggle_menu"))
		get_viewport().set_input_as_handled()


## Toggle overlay visibility (instantiate on first call, show/hide on subsequent)
func toggle_overlay(overlay_id: StringName) -> void:
	# Guard against rapid toggle race condition
	if _instantiating.get(overlay_id, false):
		return

	# Check if overlay exists
	var overlay_instance: Node = _overlay_instances.get(overlay_id)

	if overlay_instance == null:
		# First toggle - instantiate overlay
		_instantiating[overlay_id] = true
		var scene_resource: PackedScene = _overlay_scenes.get(overlay_id)

		if scene_resource == null:
			push_error("Debug Manager: Unknown overlay ID: %s" % overlay_id)
			_instantiating[overlay_id] = false
			return

		overlay_instance = scene_resource.instantiate()
		add_child(overlay_instance)
		_overlay_instances[overlay_id] = overlay_instance
		_instantiating[overlay_id] = false

		U_DEBUG_TELEMETRY.log_debug(StringName("debug"), "Overlay instantiated: %s" % overlay_id)
	else:
		# Subsequent toggle - show/hide
		overlay_instance.visible = not overlay_instance.visible
		U_DEBUG_TELEMETRY.log_debug(StringName("debug"), "Overlay toggled: %s (visible=%s)" % [overlay_id, overlay_instance.visible])


## Get current overlay visibility state
func is_overlay_visible(overlay_id: StringName) -> bool:
	var overlay_instance: Node = _overlay_instances.get(overlay_id)
	return overlay_instance != null and overlay_instance.visible


## Subscribe to events for telemetry logging
func _subscribe_to_telemetry_events() -> void:
	# ECS Events via U_ECSEventBus
	U_ECS_EVENT_BUS.checkpoint_activated.connect(_on_checkpoint_activated)
	U_ECS_EVENT_BUS.entity_death.connect(_on_entity_death)
	U_ECS_EVENT_BUS.save_started.connect(_on_save_started)
	U_ECS_EVENT_BUS.save_completed.connect(_on_save_completed)
	U_ECS_EVENT_BUS.save_failed.connect(_on_save_failed)

	# Redux actions via action_dispatched signal
	if _store:
		_store.action_dispatched.connect(_on_action_dispatched)


## Handle slice updates (for time scale)
func _on_slice_updated(slice_name: StringName, _slice_data: Dictionary) -> void:
	if slice_name == StringName("debug") and _store:
		var state: Dictionary = _store.get_state()
		var time_scale: float = U_DEBUG_SELECTORS.get_time_scale(state)
		Engine.time_scale = time_scale


## Telemetry event handlers
func _on_checkpoint_activated(checkpoint_id: StringName) -> void:
	U_DEBUG_TELEMETRY.log_info(StringName("checkpoint"), "Checkpoint activated", {"checkpoint_id": checkpoint_id})


func _on_entity_death(entity_id: StringName) -> void:
	U_DEBUG_TELEMETRY.log_info(StringName("gameplay"), "Entity death", {"entity_id": entity_id})


func _on_save_started(slot_id: StringName) -> void:
	U_DEBUG_TELEMETRY.log_info(StringName("save"), "Save started", {"slot_id": slot_id})


func _on_save_completed(slot_id: StringName) -> void:
	U_DEBUG_TELEMETRY.log_info(StringName("save"), "Save completed", {"slot_id": slot_id})


func _on_save_failed(slot_id: StringName, error_code: int) -> void:
	U_DEBUG_TELEMETRY.log_error(StringName("save"), "Save failed", {"slot_id": slot_id, "error_code": error_code})


## Handle Redux actions for telemetry
func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: String = action.get("type", "")

	match action_type:
		"scene/transition_completed":
			var scene_id: StringName = action.get("payload", {}).get("scene_id", StringName(""))
			U_DEBUG_TELEMETRY.log_info(StringName("scene"), "Scene transition completed", {"scene_id": scene_id})
		"gameplay/take_damage":
			var entity_id: StringName = action.get("payload", {}).get("entity_id", StringName(""))
			var amount: float = action.get("payload", {}).get("amount", 0.0)
			U_DEBUG_TELEMETRY.log_debug(StringName("gameplay"), "Damage taken", {"entity_id": entity_id, "amount": amount})
		"gameplay/reset_after_death":
			U_DEBUG_TELEMETRY.log_info(StringName("gameplay"), "Reset after death (respawn)")


## Cleanup old log files (>7 days)
func _cleanup_old_logs() -> void:
	var logs_dir := "user://logs/"

	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(logs_dir):
		DirAccess.make_dir_absolute(logs_dir)
		return

	var dir := DirAccess.open(logs_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var current_time := Time.get_unix_time_from_system()
	var seven_days_seconds: float = 7.0 * 24.0 * 60.0 * 60.0

	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path := logs_dir + file_name
			var modified_time := FileAccess.get_modified_time(file_path)

			if current_time - modified_time > seven_days_seconds:
				dir.remove(file_name)
				U_DEBUG_TELEMETRY.log_debug(StringName("system"), "Deleted old log file", {"file": file_name})

		file_name = dir.get_next()

	dir.list_dir_end()


## Save session log on exit
func _save_session_log() -> void:
	var logs_dir := "user://logs/"

	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(logs_dir):
		DirAccess.make_dir_absolute(logs_dir)

	# Generate timestamp filename
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var file_path := logs_dir + "debug_session_%s.json" % timestamp

	# Export to file
	var error := U_DEBUG_TELEMETRY.export_to_file(file_path)

	if error == OK:
		print("Debug Manager: Session log saved to %s" % file_path)
	else:
		push_error("Debug Manager: Failed to save session log: %s" % error)
