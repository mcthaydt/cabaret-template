@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_CheckpointHandlerSystem

const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")

## Injected state store (for testing)
## If set, system uses this instead of U_StateUtils.get_store()
@export var state_store: I_StateStore = null

var _store: I_StateStore = null
var _event_unsubscribes: Array[Callable] = []

func _init() -> void:
	execution_priority = 100

func on_configured() -> void:
	_subscribe_events()

func process_tick(__delta: float) -> void:
	# Event-driven system.
	pass

func _subscribe_events() -> void:
	_event_unsubscribes.append(U_ECSEventBus.subscribe(
		U_ECSEventNames.EVENT_CHECKPOINT_ACTIVATION_REQUESTED,
		_on_checkpoint_activation_requested
	))

func _on_checkpoint_activation_requested(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var checkpoint := payload.get("checkpoint") as C_CheckpointComponent
	var spawn_point_id: StringName = payload.get("spawn_point_id", StringName(""))
	if checkpoint == null:
		push_warning("S_CheckpointHandlerSystem: checkpoint_activation_requested missing required payload.checkpoint")
		return
	if spawn_point_id == StringName(""):
		push_warning("S_CheckpointHandlerSystem: checkpoint_activation_requested missing required payload.spawn_point_id")
		return

	if checkpoint.is_activated and checkpoint.spawn_point_id == spawn_point_id:
		return

	checkpoint.activate()

	if _store == null:
		if state_store != null:
			_store = state_store
		else:
			_store = U_STATE_UTILS.get_store(self)

	if _store != null:
		var action: Dictionary = U_GAMEPLAY_ACTIONS.set_last_checkpoint(spawn_point_id)
		_store.dispatch(action)

	var spawn_position := _resolve_spawn_point_position(spawn_point_id)
	var checkpoint_event := Evn_CheckpointActivated.new(
		checkpoint.checkpoint_id,
		checkpoint.spawn_point_id,
		spawn_position
	)
	U_ECSEventBus.publish_typed(checkpoint_event)

func _resolve_spawn_point_position(spawn_point_id: StringName) -> Vector3:
	if spawn_point_id == StringName(""):
		return Vector3.ZERO

	var tree := get_tree()
	if tree == null:
		return Vector3.ZERO

	var root: Node = tree.current_scene
	if root == null:
		root = tree.root

	if root == null:
		return Vector3.ZERO

	var node := root.find_child(String(spawn_point_id), true, false) as Node3D
	if node == null or not is_instance_valid(node):
		return Vector3.ZERO

	return node.global_position

func _exit_tree() -> void:
	for unsubscribe in _event_unsubscribes:
		if unsubscribe != null and unsubscribe is Callable and (unsubscribe as Callable).is_valid():
			(unsubscribe as Callable).call()
	_event_unsubscribes.clear()
