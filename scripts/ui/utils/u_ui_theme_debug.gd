extends RefCounted
class_name U_UIThemeDebug

## Centralized debug logger for UI theme startup/registration tracing.
## Enabled on mobile debug builds by default, or on desktop with:
##   --ui-theme-debug

const FORCE_DEBUG_ARG := "--ui-theme-debug"

static func is_enabled() -> bool:
	if not OS.is_debug_build():
		return false
	if OS.has_feature("mobile"):
		return true
	var args: PackedStringArray = OS.get_cmdline_args()
	return args.has(FORCE_DEBUG_ARG)

static func log(source: String, message: String) -> void:
	if not is_enabled():
		return
	print("[UIThemeDebug][%s] %s" % [source, message])
