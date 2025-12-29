extends RefCounted
class_name U_DebugTelemetry

## Debug Telemetry - Session logging and export (Phase 0 stub, full implementation in Phase 2)
##
## This is a minimal stub implementation to make Phase 0 functional.
## Full implementation with tests, structured logging, and export features in Phase 2.

enum LogLevel {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3,
}

# Session log storage
static var _session_log: Array = []
static var _session_start_time: float = 0.0

## Initialize session (called automatically on first log)
static func _ensure_initialized() -> void:
	if _session_start_time == 0.0:
		_session_start_time = Time.get_unix_time_from_system()
		_session_log.clear()
		_log_internal(LogLevel.INFO, StringName("system"), "Debug session started", {})

## Core logging method (renamed to avoid conflict with built-in log function)
static func write_log(level: LogLevel, category: StringName, message: String, data: Dictionary = {}) -> void:
	_ensure_initialized()
	_log_internal(level, category, message, data)

## Convenience methods
static func log_debug(category: StringName, message: String, data: Dictionary = {}) -> void:
	write_log(LogLevel.DEBUG, category, message, data)

static func log_info(category: StringName, message: String, data: Dictionary = {}) -> void:
	write_log(LogLevel.INFO, category, message, data)

static func log_warn(category: StringName, message: String, data: Dictionary = {}) -> void:
	write_log(LogLevel.WARN, category, message, data)

static func log_error(category: StringName, message: String, data: Dictionary = {}) -> void:
	write_log(LogLevel.ERROR, category, message, data)

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

	# Console output with color coding (basic for Phase 0)
	var level_str: String = LogLevel.keys()[level]
	var prefix := "[%.3fs] [%s] [%s]" % [timestamp, level_str, category]

	if data.is_empty():
		print("%s %s" % [prefix, message])
	else:
		print("%s %s | %s" % [prefix, message, JSON.stringify(data)])

## Get session log (returns copy)
static func get_session_log() -> Array:
	return _session_log.duplicate(true)

## Clear session log
static func clear_session_log() -> void:
	_session_log.clear()

## Export to file (minimal implementation for Phase 0)
static func export_to_file(path: String) -> Error:
	_ensure_initialized()

	var session_data: Dictionary = {
		"session_start": Time.get_datetime_string_from_unix_time(_session_start_time),
		"session_end": Time.get_datetime_string_from_system(),
		"build_id": ProjectSettings.get_setting("application/config/version", "unknown"),
		"entries": _session_log.duplicate(true),
	}

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
	_ensure_initialized()

	var session_data: Dictionary = {
		"session_start": Time.get_datetime_string_from_unix_time(_session_start_time),
		"session_end": Time.get_datetime_string_from_system(),
		"build_id": ProjectSettings.get_setting("application/config/version", "unknown"),
		"entries": _session_log.duplicate(true),
	}

	DisplayServer.clipboard_set(JSON.stringify(session_data, "\t"))
	log_info(StringName("system"), "Session log copied to clipboard")
