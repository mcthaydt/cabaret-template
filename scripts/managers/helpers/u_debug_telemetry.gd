extends RefCounted
class_name U_DebugTelemetry

## Debug Telemetry - Session logging and export (Phase 2 - TDD Implementation)
##
## Provides structured logging with levels, categories, and automatic session export.
## Logs are accumulated in-memory and can be exported to file or clipboard.

const U_DEBUG_CONSOLE_FORMATTER := preload("res://scripts/managers/helpers/u_debug_console_formatter.gd")

enum LogLevel {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3,
}

# Session log storage
static var _session_log: Array = []
static var _session_start_time: float = 0.0
static var _is_initialized: bool = false

## Initialize session (called automatically on first log)
static func _ensure_initialized() -> void:
	if not _is_initialized:
		_session_start_time = Time.get_unix_time_from_system()
		_session_log.clear()
		_is_initialized = true
		# Note: Don't auto-log "Session started" to avoid affecting test expectations
		# Tests can verify initialization through their own log calls

## Core logging method
## @param level: Log severity level (DEBUG/INFO/WARN/ERROR)
## @param category: Category tag for filtering (e.g., "scene", "gameplay", "save")
## @param message: Human-readable message
## @param data: Optional structured data dictionary
## Note: Named 'add_log' instead of 'log' to avoid conflict with GDScript's built-in log() function
static func add_log(level: LogLevel, category: StringName, message: String, data: Dictionary = {}) -> void:
	_ensure_initialized()
	_log_internal(level, category, message, data)

## Convenience methods
static func log_debug(category: StringName, message: String, data: Dictionary = {}) -> void:
	add_log(LogLevel.DEBUG, category, message, data)

static func log_info(category: StringName, message: String, data: Dictionary = {}) -> void:
	add_log(LogLevel.INFO, category, message, data)

static func log_warn(category: StringName, message: String, data: Dictionary = {}) -> void:
	add_log(LogLevel.WARN, category, message, data)

static func log_error(category: StringName, message: String, data: Dictionary = {}) -> void:
	add_log(LogLevel.ERROR, category, message, data)

## Internal logging implementation
static func _log_internal(level: LogLevel, category: StringName, message: String, data: Dictionary) -> void:
	var timestamp: float = Time.get_unix_time_from_system() - _session_start_time

	var entry: Dictionary = {
		"timestamp": timestamp,
		"level": LogLevel.keys()[level],
		"category": String(category),
		"message": message,
		"data": data.duplicate(true),
	}

	_session_log.append(entry)

	# Console output with color coding
	var formatted := U_DEBUG_CONSOLE_FORMATTER.format_entry(entry)
	print(formatted)

## Get session log (returns deep copy to prevent external mutation)
static func get_session_log() -> Array:
	return _session_log.duplicate(true)

## Clear session log
static func clear_session_log() -> void:
	_session_log.clear()
	_is_initialized = false
	_session_start_time = 0.0

## Get export data structure (used by file and clipboard export)
## Returns: Dictionary with session_start, session_end, build_id, entries
static func get_export_data() -> Dictionary:
	_ensure_initialized()

	return {
		"session_start": Time.get_datetime_string_from_unix_time(_session_start_time),
		"session_end": Time.get_datetime_string_from_system(),
		"build_id": ProjectSettings.get_setting("application/config/version", "unknown"),
		"entries": _session_log.duplicate(true),
	}

## Export to file
## @param path: File path to write to (e.g., "user://logs/session.json")
## @returns: OK on success, error code on failure
static func export_to_file(path: String) -> Error:
	var session_data: Dictionary = get_export_data()

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var error := FileAccess.get_open_error()
		push_error("U_DebugTelemetry: Failed to open file for writing: %s (error: %s)" % [path, error])
		return error

	file.store_string(JSON.stringify(session_data, "\t"))
	file.close()

	return OK

## Export to clipboard
static func export_to_clipboard() -> void:
	var session_data: Dictionary = get_export_data()
	DisplayServer.clipboard_set(JSON.stringify(session_data, "\t"))
	log_info(StringName("system"), "Session log copied to clipboard")
