extends RefCounted
class_name U_DebugConsoleFormatter

## Debug Console Formatter - Color-coded console output for telemetry (utility)
##
## Provides ANSI color codes and formatting for debug log entries displayed in the console.
## Separates presentation logic from telemetry logging logic.

# ANSI color codes for console output
const COLOR_RESET := "\u001b[0m"
const COLOR_DEBUG := "\u001b[90m"     # Gray
const COLOR_INFO := "\u001b[37m"      # White
const COLOR_WARN := "\u001b[33m"      # Yellow
const COLOR_ERROR := "\u001b[31m"     # Red

## Format a log entry for console output
## @param entry: Dictionary with timestamp, level, category, message, data
## @returns: Formatted string with ANSI colors
static func format_entry(entry: Dictionary) -> String:
	var timestamp: float = entry.get("timestamp", 0.0)
	var level: String = entry.get("level", "INFO")
	var category: String = str(entry.get("category", ""))
	var message: String = entry.get("message", "")
	var data: Dictionary = entry.get("data", {})

	# Convert timestamp to HH:MM:SS format
	var time_str := _format_timestamp(timestamp)

	# Get color for level
	var color := _get_level_color(level)

	# Build formatted string
	var prefix := "%s[%s] [%s] [%s]%s" % [color, time_str, level, category, COLOR_RESET]

	if data.is_empty():
		return "%s %s" % [prefix, message]
	else:
		return "%s %s | %s" % [prefix, message, JSON.stringify(data)]

## Format timestamp as HH:MM:SS
static func _format_timestamp(seconds: float) -> String:
	var total_seconds := int(seconds)
	var hours := total_seconds / 3600
	var minutes := (total_seconds % 3600) / 60
	var secs := total_seconds % 60

	return "%02d:%02d:%02d" % [hours, minutes, secs]

## Get ANSI color code for log level
static func _get_level_color(level: String) -> String:
	match level:
		"DEBUG":
			return COLOR_DEBUG
		"INFO":
			return COLOR_INFO
		"WARN":
			return COLOR_WARN
		"ERROR":
			return COLOR_ERROR
		_:
			return COLOR_INFO  # Default to white
