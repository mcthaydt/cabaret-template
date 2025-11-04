@icon("res://resources/editor_icons/system.svg")
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
## - M_SpawnManager.spawn_at_last_spawn() checks last_checkpoint first
## - Priority: last_checkpoint > target_spawn_point > sp_default

const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")

var _connected_checkpoints: Dictionary = {}  # Track which checkpoints we've already connected

func _ready() -> void:
	# Set priority (checkpoints are low priority, process after gameplay systems)
	process_priority = 100
	super._ready()

## Connect to checkpoint Area3D signals
func process_tick(_delta: float) -> void:
	var manager = get_manager()
	if manager == null:
		return

	# Query for all entities with checkpoint components
	var checkpoints: Array = manager.query_entities([C_CheckpointComponent.COMPONENT_TYPE])

	for checkpoint_data in checkpoints:
		var checkpoint: C_CheckpointComponent = checkpoint_data.get_component(C_CheckpointComponent.COMPONENT_TYPE)
		if checkpoint == null:
			continue

		# Skip if already connected
		if _connected_checkpoints.has(checkpoint):
			continue

		# Find Area3D child
		var area: Area3D = _find_area3d_in_checkpoint(checkpoint)
		if area == null:
			continue

		# Connect to body_entered signal
		if not area.body_entered.is_connected(_on_checkpoint_body_entered):
			area.body_entered.connect(_on_checkpoint_body_entered.bind(checkpoint))
			_connected_checkpoints[checkpoint] = true

## Find Area3D child in checkpoint component
func _find_area3d_in_checkpoint(checkpoint: C_CheckpointComponent) -> Area3D:
	for child in checkpoint.get_children():
		if child is Area3D:
			return child as Area3D
	return null

## Called when any body enters checkpoint area
func _on_checkpoint_body_entered(body: Node3D, checkpoint: C_CheckpointComponent) -> void:
	# Check if body is the player
	if not _is_player(body):
		return

	# Activate checkpoint
	checkpoint.activate()

	# Update last_checkpoint in gameplay state
	var store = U_STATE_UTILS.get_store(self)
	if store != null:
		var action: Dictionary = U_GAMEPLAY_ACTIONS.set_last_checkpoint(checkpoint.spawn_point_id)
		store.dispatch(action)

		print("Checkpoint activated: %s (spawn at: %s)" % [checkpoint.checkpoint_id, checkpoint.spawn_point_id])

	# TODO: Visual/audio feedback (particle effect, sound, etc.)

## Check if body is the player entity
func _is_player(body: Node3D) -> bool:
	if body == null:
		return false

	# Check if node name starts with "E_Player"
	return body.name.begins_with("E_Player")
