extends RefCounted
class_name U_RunActions

## Action creators for run-level orchestration.

const ACTION_RESET_RUN := StringName("run/reset")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_RESET_RUN)

static func reset_run(next_route: StringName = StringName("retry_alleyway")) -> Dictionary:
	return {
		"type": ACTION_RESET_RUN,
		"payload": {
			"next_route": next_route,
		}
	}
