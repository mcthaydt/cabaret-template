extends RefCounted
class_name U_SceneDirectorActions

## Action creators for scene_director slice.

const ACTION_START_DIRECTIVE := StringName("scene_director/start_directive")
const ACTION_ADVANCE_BEAT := StringName("scene_director/advance_beat")
const ACTION_COMPLETE_DIRECTIVE := StringName("scene_director/complete_directive")
const ACTION_RESET := StringName("scene_director/reset")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_START_DIRECTIVE)
	U_ActionRegistry.register_action(ACTION_ADVANCE_BEAT)
	U_ActionRegistry.register_action(ACTION_COMPLETE_DIRECTIVE)
	U_ActionRegistry.register_action(ACTION_RESET)

static func start_directive(directive_id: StringName) -> Dictionary:
	return {
		"type": ACTION_START_DIRECTIVE,
		"payload": directive_id
	}

static func advance_beat() -> Dictionary:
	return {
		"type": ACTION_ADVANCE_BEAT,
		"payload": null
	}

static func complete_directive() -> Dictionary:
	return {
		"type": ACTION_COMPLETE_DIRECTIVE,
		"payload": null
	}

static func reset() -> Dictionary:
	return {
		"type": ACTION_RESET,
		"payload": null
	}

