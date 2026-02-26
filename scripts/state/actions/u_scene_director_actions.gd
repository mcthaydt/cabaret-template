extends RefCounted
class_name U_SceneDirectorActions

## Action creators for scene_director slice.

const ACTION_START_DIRECTIVE := StringName("scene_director/start_directive")
const ACTION_ADVANCE_BEAT := StringName("scene_director/advance_beat")
const ACTION_SET_BEAT_INDEX := StringName("scene_director/set_beat_index")
const ACTION_SET_CURRENT_BEAT := StringName("scene_director/set_current_beat")
const ACTION_SET_ACTIVE_BEATS := StringName("scene_director/set_active_beats")
const ACTION_START_PARALLEL := StringName("scene_director/start_parallel")
const ACTION_COMPLETE_PARALLEL := StringName("scene_director/complete_parallel")
const ACTION_COMPLETE_DIRECTIVE := StringName("scene_director/complete_directive")
const ACTION_RESET := StringName("scene_director/reset")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_START_DIRECTIVE)
	U_ActionRegistry.register_action(ACTION_ADVANCE_BEAT)
	U_ActionRegistry.register_action(ACTION_SET_BEAT_INDEX)
	U_ActionRegistry.register_action(ACTION_SET_CURRENT_BEAT)
	U_ActionRegistry.register_action(ACTION_SET_ACTIVE_BEATS)
	U_ActionRegistry.register_action(ACTION_START_PARALLEL)
	U_ActionRegistry.register_action(ACTION_COMPLETE_PARALLEL)
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

static func set_beat_index(beat_index: int) -> Dictionary:
	return {
		"type": ACTION_SET_BEAT_INDEX,
		"payload": beat_index
	}

static func set_current_beat(beat_id: StringName) -> Dictionary:
	return {
		"type": ACTION_SET_CURRENT_BEAT,
		"payload": beat_id
	}

static func set_active_beats(beat_ids: Array[StringName]) -> Dictionary:
	return {
		"type": ACTION_SET_ACTIVE_BEATS,
		"payload": beat_ids.duplicate()
	}

static func start_parallel(lane_beat_ids: Array[StringName]) -> Dictionary:
	return {
		"type": ACTION_START_PARALLEL,
		"payload": lane_beat_ids.duplicate()
	}

static func complete_parallel() -> Dictionary:
	return {
		"type": ACTION_COMPLETE_PARALLEL,
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
