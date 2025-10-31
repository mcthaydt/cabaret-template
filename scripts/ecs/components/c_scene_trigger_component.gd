@icon("res://resources/editor_icons/component.svg")
extends BaseECSComponent
class_name C_SceneTriggerComponent

## Scene Trigger Component
##
## ECS component for door triggers and area transitions (Zelda OoT-style).
## Handles collision detection and triggering scene transitions when player
## enters/exits gameplay areas.
##
## Trigger Modes:
## - AUTO: Automatically triggers transition when player enters Area3D
## - INTERACT: Requires player to press interact key while in Area3D
##
## Usage:
## 1. Add to entity node (must have E_ prefix)
## 2. Configure door_id, target_scene_id, target_spawn_point
## 3. Set trigger_mode (AUTO or INTERACT)
## 4. S_SceneTriggerSystem handles detection and transition logic

const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_SceneRegistry := preload("res://scripts/scene_management/u_scene_registry.gd")

## Trigger mode enum
enum TriggerMode {
	AUTO = 0,      # Automatic transition on collision
	INTERACT = 1   # Requires interact input while in collision
}

## Component type constant
const COMPONENT_TYPE := StringName("C_SceneTriggerComponent")

func _init() -> void:
	component_type = COMPONENT_TYPE

## Door ID (unique identifier for this door/trigger)
@export var door_id: StringName = StringName("")

## Target scene to transition to
@export var target_scene_id: StringName = StringName("")

## Spawn point in target scene (Node3D name)
@export var target_spawn_point: StringName = StringName("")

## Trigger mode (AUTO or INTERACT)
@export var trigger_mode: TriggerMode = TriggerMode.AUTO

## Cooldown duration in seconds (prevent rapid re-triggering)
@export var cooldown_duration: float = 1.0

## Internal: Cooldown timer
var _cooldown_remaining: float = 0.0

## Internal: Area3D for collision detection
var _trigger_area: Area3D = null

## Internal: Player currently in trigger zone
var _player_in_zone: bool = false

## Internal: Prevent duplicate transitions while a transition is pending
var _pending_transition: bool = false

func _ready() -> void:
	super._ready()

	# Create Area3D for collision detection
	_create_trigger_area()

## Create Area3D child for collision detection
func _create_trigger_area() -> void:
	_trigger_area = Area3D.new()
	_trigger_area.name = "TriggerArea"
	_trigger_area.collision_layer = 0  # Don't collide with anything
	_trigger_area.collision_mask = 1   # Detect layer 1 (player)
	_trigger_area.monitoring = true    # Explicitly enable detection
	add_child(_trigger_area)

	# Create collision shape (box)
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	# Offset upward to match player hover height (1.5m)
	collision_shape.position = Vector3(0, 1.5, 0)
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(2.0, 4.0, 2.0)  # Taller box for better detection (y=-0.5 to y=+3.5)
	collision_shape.shape = box_shape
	_trigger_area.add_child(collision_shape)

	# Connect signals
	_trigger_area.body_entered.connect(_on_body_entered)
	_trigger_area.body_exited.connect(_on_body_exited)

## Process cooldown timer
func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta

	# Reset pending flag when cooldown elapses to allow future triggers
	if _pending_transition and _cooldown_remaining <= 0.0:
		_pending_transition = false

## Callback when body enters trigger area
func _on_body_entered(body: Node3D) -> void:
	# Check if it's the player (check body or its owner for "player" group)
	print_debug("[SceneTrigger] body_entered: ", body,
		" in_player_zone_before=", _player_in_zone,
		" cooldown_remaining=", _cooldown_remaining,
		" pending=", _pending_transition,
		" trigger_mode=", trigger_mode)
	if _is_player(body):
		_player_in_zone = true
		# If AUTO mode, trigger transition immediately
		if trigger_mode == TriggerMode.AUTO and _can_trigger():
			_trigger_transition()
		else:
			print_debug("[SceneTrigger] body_entered: player but cannot trigger; mode=", trigger_mode)
	else:
		print_debug("[SceneTrigger] body_entered: non-player body=", body)

## Callback when body exits trigger area
func _on_body_exited(body: Node3D) -> void:
	if _is_player(body):
		_player_in_zone = false
		print_debug("[SceneTrigger] body_exited: ", body)

## Check if body belongs to player entity
func _is_player(body: Node3D) -> bool:
	# Check if body itself is in player group
	if body.is_in_group("player"):
		return true

	# Check if body's parent is in player group (E_PlayerRoot owns Player_Body)
	var parent := body.get_parent()
	if parent != null and parent.is_in_group("player"):
		return true

	# Check scene owner (for instanced scenes)
	var owner_node := body.owner
	if owner_node != null and owner_node.is_in_group("player"):
		return true

	print_debug("[SceneTrigger] _is_player: NOT player; body=", body, " parent=", body.get_parent())
	return false

## Check if trigger can fire (not on cooldown)
func _can_trigger() -> bool:
	if _pending_transition:
		print_debug("[SceneTrigger] _can_trigger: false (pending_transition)")
		return false

	if _cooldown_remaining > 0.0:
		print_debug("[SceneTrigger] _can_trigger: false (cooldown ", _cooldown_remaining, ")")
		return false

	# Guard against re-entry while a scene transition is underway
	var store = U_StateUtils.get_store(self)
	if store != null:
		var scene_state: Dictionary = store.get_slice(StringName("scene"))
		if scene_state.get("is_transitioning", false):
			print_debug("[SceneTrigger] _can_trigger: false (scene.is_transitioning)")
			return false

	# Also check SceneManager if available
	var managers: Array = get_tree().get_nodes_in_group("scene_manager")
	if managers.size() > 0:
		var mgr = managers[0]
		if mgr != null and mgr.has_method("is_transitioning") and mgr.is_transitioning():
			print_debug("[SceneTrigger] _can_trigger: false (manager.is_transitioning)")
			return false

	return true

## Trigger the scene transition
func _trigger_transition() -> void:
	# Start cooldown
	_cooldown_remaining = cooldown_duration

	# Get state store
	var store = U_StateUtils.get_store(self)
	if store == null:
		push_error("C_SceneTriggerComponent: No M_StateStore found")
		return

	# Dispatch set_target_spawn_point action
	var spawn_action: Dictionary = U_GameplayActions.set_target_spawn_point(target_spawn_point)
	store.dispatch(spawn_action)

	# Get scene manager
	var scene_manager_group: Array = get_tree().get_nodes_in_group("scene_manager")
	if scene_manager_group.is_empty():
		push_error("C_SceneTriggerComponent: No M_SceneManager found in 'scene_manager' group")
		return

	var scene_manager = scene_manager_group[0]

	# Final guard before requesting transition
	if not _can_trigger():
		return

	# Mark pending to avoid duplicate requests within the same cooldown window
	_pending_transition = true

	# Trigger scene transition
	# Get transition type from door pairing
	var door_data: Dictionary = U_SceneRegistry.get_door_exit(
		_get_current_scene_id(store),
		door_id
	)
	var transition_type: String = door_data.get("transition_type", "fade")
	print_debug("[SceneTrigger] triggering: door_id=", door_id, " target_scene=", target_scene_id, 
		" spawn=", target_spawn_point, " current_scene=", _get_current_scene_id(store), 
		" transition_type=", transition_type)
	scene_manager.transition_to_scene(target_scene_id, transition_type, scene_manager.Priority.HIGH)

## Get current scene ID from state
func _get_current_scene_id(store) -> StringName:
	var state: Dictionary = store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	return scene_state.get("current_scene_id", StringName(""))

## Check if player is in trigger zone (for INTERACT mode)
func is_player_in_zone() -> bool:
	return _player_in_zone

## Manually trigger transition (for INTERACT mode)
func trigger_interact() -> void:
	if _player_in_zone and _can_trigger():
		_trigger_transition()
