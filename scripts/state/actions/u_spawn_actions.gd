extends RefCounted
class_name U_SpawnActions

## Action creators for spawn lifecycle notifications
##
## Replaces ECS event bus publishes from M_SpawnManager per channel taxonomy
## (docs/adr/0001-channel-taxonomy.md). Managers dispatch to Redux only;
## subscribers connect to M_StateStore.action_dispatched and filter by type.

const ACTION_PLAYER_SPAWNED := StringName("spawn/player_spawned")

static func _static_init() -> void:
	U_ActionRegistry.register_action(ACTION_PLAYER_SPAWNED)

static func player_spawned(position: Vector3, spawn_point_id: StringName) -> Dictionary:
	return {
		"type": ACTION_PLAYER_SPAWNED,
		"position": position,
		"spawn_point_id": spawn_point_id,
	}