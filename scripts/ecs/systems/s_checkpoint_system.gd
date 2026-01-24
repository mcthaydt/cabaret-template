@icon("res://assets/editor_icons/system.svg")
extends BaseECSSystem
class_name S_CheckpointSystem

## Checkpoint System (Phase 12.3b - T266)
##
## Detects when player enters checkpoint areas and updates last_checkpoint in state.
## Checkpoints allow mid-scene respawn points independent of door transitions.
##
## Query: C_CheckpointComponent
##
## Responsibilities:
## - Connect to Area3D.body_entered signals on checkpoints
## - Detect player collision with checkpoints
## - Dispatch action to set last_checkpoint in gameplay state
## - Optional: Visual/audio feedback on checkpoint activation
##
## Integration:
## - M_SpawnManager.spawn_at_last_spawn() checks in this order:
##   target_spawn_point → last_checkpoint → sp_default

const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_ECSUtils := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const EVENT_CHECKPOINT_ZONE_ENTERED := StringName("checkpoint_zone_entered")
const EVENT_CHECKPOINT_ACTIVATED := StringName("checkpoint_activated")

const PLAYER_TAG_COMPONENT := StringName("C_PlayerTagComponent")

## Injected state store (for testing)
## If set, system uses this instead of U_StateUtils.get_store()
## Phase 10B-8 (T142c): Enable dependency injection for isolated testing
@export var state_store: I_StateStore = null

var _store: I_StateStore = null
var _event_unsubscribes: Array[Callable] = []

func _ready() -> void:
	# Set priority (checkpoints are low priority, process after gameplay systems)
	execution_priority = 100
	super._ready()

func on_configured() -> void:
	_subscribe_events()

func process_tick(_delta: float) -> void:
	# No-op; event-driven
	pass

func _subscribe_events() -> void:
	_event_unsubscribes.append(U_ECSEventBus.subscribe(EVENT_CHECKPOINT_ZONE_ENTERED, _on_checkpoint_zone_entered))

func _on_checkpoint_zone_entered(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var checkpoint := payload.get("checkpoint") as C_CheckpointComponent
	var spawn_point_id: StringName = payload.get("spawn_point_id", StringName(""))
	if checkpoint == null or checkpoint.is_activated and checkpoint.spawn_point_id == spawn_point_id:
		return

	checkpoint.activate()

	if _store == null:
		# Use injected store if available (Phase 10B-8)
		if state_store != null:
			_store = state_store
		else:
			_store = U_STATE_UTILS.get_store(self)

	if _store != null:
		var action: Dictionary = U_GAMEPLAY_ACTIONS.set_last_checkpoint(spawn_point_id)
		_store.dispatch(action)

	var checkpoint_event := Evn_CheckpointActivated.new(
		checkpoint.checkpoint_id,
		checkpoint.spawn_point_id
	)
	U_ECSEventBus.publish_typed(checkpoint_event)

func _exit_tree() -> void:
	for unsubscribe in _event_unsubscribes:
		if unsubscribe != null and unsubscribe is Callable and (unsubscribe as Callable).is_valid():
			(unsubscribe as Callable).call()
	_event_unsubscribes.clear()
