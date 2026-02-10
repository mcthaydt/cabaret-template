extends RefCounted
class_name U_DebugActions


const ACTION_SET_DISABLE_TOUCHSCREEN := StringName("debug/set_disable_touchscreen")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_SET_DISABLE_TOUCHSCREEN)

static func set_disable_touchscreen(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_SET_DISABLE_TOUCHSCREEN,
		"payload": {
			"enabled": enabled
		},
		"immediate": true
	}
