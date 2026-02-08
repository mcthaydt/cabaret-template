@icon("res://assets/editor_icons/icn_component.svg")
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

const PLAYER_TAG_COMPONENT_TYPE := StringName("C_PlayerTagComponent")

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

## Optional: Reuse an authored Area3D instead of auto-creating one (set by controllers)
@export_node_path("Area3D") var area_path: NodePath

## Internal: Cooldown timer
var _cooldown_remaining: float = 0.0

## Internal: Area3D for collision detection
var _trigger_area: Area3D = null

## Internal: Player currently in trigger zone
var _player_in_zone: bool = false

## Internal: Prevent duplicate transitions while a transition is pending
var _pending_transition: bool = false

## Internal: Arm flag to ignore first-frame overlaps after scene load
var _armed: bool = false

func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	_resolve_or_create_trigger_area()
	call_deferred("_arm_trigger")

func _arm_trigger() -> void:
	await get_tree().physics_frame
	_armed = true

## Return the trigger Area3D, resolving/creating it on-demand if needed.
func get_trigger_area() -> Area3D:
	if _trigger_area != null and is_instance_valid(_trigger_area):
		return _trigger_area

	_resolve_or_create_trigger_area()
	return _trigger_area

## Resolve or create the Area3D used for collision detection
func _resolve_or_create_trigger_area() -> void:
	if _trigger_area != null and is_instance_valid(_trigger_area):
		return

	var resolved: Area3D = _resolve_area_from_path()
	var created_new: bool = false

	if resolved == null:
		resolved = _find_existing_area()

	if resolved == null:
		resolved = _create_new_area()
		created_new = true

	if resolved == null:
		push_error("C_SceneTriggerComponent: Unable to resolve or create trigger area.")
		return

	_trigger_area = resolved
	_configure_trigger_area(_trigger_area, created_new)

func _resolve_area_from_path() -> Area3D:
	if area_path.is_empty():
		return null
	return get_node_or_null(area_path) as Area3D

func _find_existing_area() -> Area3D:
	for child in get_children():
		if child is Area3D:
			return child as Area3D
	var parent_node := get_parent()
	if parent_node != null:
		for sibling in parent_node.get_children():
			if sibling is Area3D:
				return sibling as Area3D
	return null

func _create_new_area() -> Area3D:
	var area := Area3D.new()
	area.name = "TriggerArea"
	var host := get_parent()
	if host is Node:
		(host as Node).add_child(area)
	else:
		add_child(area)
	return area

func _configure_trigger_area(area: Area3D, force_shape_from_settings: bool) -> void:
	if area == null:
		return

	area.monitoring = true
	area.monitorable = true
	area.collision_layer = 0
	area.collision_mask = max(1, _get_settings().player_mask)

	_ensure_collision_shape(area, force_shape_from_settings)

	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)
	if not area.body_exited.is_connected(_on_body_exited):
		area.body_exited.connect(_on_body_exited)

	if area_path.is_empty():
		var parent := get_parent()
		if parent != null:
			var relative := parent.get_path_to(area)
			if not relative.is_empty():
				area_path = relative

func _ensure_collision_shape(area: Area3D, apply_settings: bool) -> void:
	var existing_shape: CollisionShape3D = null
	for child in area.get_children():
		if child is CollisionShape3D:
			existing_shape = child as CollisionShape3D
			break

	if existing_shape == null:
		existing_shape = CollisionShape3D.new()
		existing_shape.name = "CollisionShape3D"
		area.add_child(existing_shape)
		apply_settings = true

	if not apply_settings:
		return

	existing_shape.position = _get_settings().local_offset

	match _get_settings().shape_type:
		RS_SceneTriggerSettings.ShapeType.CYLINDER:
			var cyl := CylinderShape3D.new()
			cyl.radius = max(0.001, _get_settings().cyl_radius)
			cyl.height = max(0.001, _get_settings().cyl_height)
			existing_shape.shape = cyl
		RS_SceneTriggerSettings.ShapeType.BOX:
			var box := BoxShape3D.new()
			box.size = _get_settings().box_size
			existing_shape.shape = box
		_:
			var cyl_fallback := CylinderShape3D.new()
			cyl_fallback.radius = 1.0
			cyl_fallback.height = 3.0
			existing_shape.shape = cyl_fallback

## Lazy-init and return settings
var _cached_settings: RS_SceneTriggerSettings = null

@export var settings: RS_SceneTriggerSettings

func _get_settings() -> RS_SceneTriggerSettings:
	if _cached_settings != null:
		return _cached_settings

	if settings == null:
		# Create a default settings instance matching previous behavior but cylindrical by default
		settings = RS_SceneTriggerSettings.new()
		settings.shape_type = RS_SceneTriggerSettings.ShapeType.CYLINDER
		settings.cyl_radius = 1.0
		settings.cyl_height = 3.0
		settings.box_size = Vector3(2.0, 3.0, 0.2)
		settings.local_offset = Vector3(0, 1.5, 0)
		settings.player_mask = 1

	_cached_settings = settings
	return _cached_settings

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
	if _is_player(body):
		_player_in_zone = true

		# Phase 8: Hint to preload target scene in background
		_hint_preload_target_scene()

		# If AUTO mode, trigger transition immediately
		if trigger_mode == TriggerMode.AUTO and _can_trigger():
			# Notify SceneManager to suppress same-frame ESC pause via ServiceLocator (Phase 10B-7: T141c)
			# Use try_get_service to avoid errors in test environments
			var mgr := U_ServiceLocator.try_get_service(StringName("scene_manager")) as I_SceneManager
			if mgr != null:
				mgr.suppress_pause_for_current_frame()

			_trigger_transition()

## Callback when body exits trigger area
func _on_body_exited(body: Node3D) -> void:
	if _is_player(body):
		_player_in_zone = false

## Check if body belongs to player entity
func _is_player(body: Node3D) -> bool:
	# ECS-based detection only: resolve entity and verify it has the player tag component
	var entity := U_ECSUtils.find_entity_root(body)
	var mgr: M_ECSManager = get_manager()
	if mgr == null:
		mgr = U_ECSUtils.get_manager(self) as M_ECSManager
	if entity == null or mgr == null:
		return false

	var comps: Dictionary = mgr.get_components_for_entity(entity)
	return comps.has(PLAYER_TAG_COMPONENT_TYPE) and comps.get(PLAYER_TAG_COMPONENT_TYPE) != null

## Check if trigger can fire (not on cooldown)
func _can_trigger() -> bool:
	if not _armed:
		return false
	if _pending_transition:
		return false

	if _cooldown_remaining > 0.0:
		return false

	# Guard against re-entry while a scene transition is underway
	var store = U_StateUtils.get_store(self)
	if store != null:
		var scene_state: Dictionary = store.get_slice(StringName("scene"))
		if scene_state.get("is_transitioning", false):
			return false

	# Also check SceneManager if available via ServiceLocator (Phase 10B-7: T141c)
	# Use try_get_service to avoid errors in test environments
	var mgr := U_ServiceLocator.try_get_service(StringName("scene_manager")) as I_SceneManager
	if mgr != null and mgr.is_transitioning():
		return false

	return true

## Trigger the scene transition
func _trigger_transition() -> void:
	# Get state store
	var store = U_StateUtils.get_store(self)
	if store == null:
		push_error("C_SceneTriggerComponent: No M_StateStore found")
		return

	# Mark pending to avoid duplicate requests within the same cooldown window
	_pending_transition = true

	# Dispatch set_target_spawn_point action
	var spawn_action: Dictionary = U_GameplayActions.set_target_spawn_point(target_spawn_point)
	store.dispatch(spawn_action)

	# Resolve scene manager via ServiceLocator
	var scene_manager := U_ServiceLocator.try_get_service(StringName("scene_manager"))
	if scene_manager == null:
		push_error("C_SceneTriggerComponent: No M_SceneManager available")
		return

	# Trigger scene transition
	# Get transition type from door pairing
	var door_data: Dictionary = U_SceneRegistry.get_door_exit(
		_get_current_scene_id(store),
		door_id
	)
	var transition_type: String = door_data.get("transition_type", "fade")
	scene_manager.transition_to_scene(target_scene_id, transition_type, scene_manager.Priority.HIGH)

	# Start cooldown after dispatching to prevent immediate re-trigger
	_cooldown_remaining = cooldown_duration

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
	# Explicit interact path should not depend on internal arm state or the
	# component's own _player_in_zone bookkeeping, since controllers already
	# validated player presence and arming on their side.
	if _can_trigger_interact():
		# Suppress same-frame ESC pause handling to avoid pause overlay during
		# door-triggered transitions when interact is used.
		# Get scene manager via ServiceLocator (Phase 10B-7: T141c)
		# Use try_get_service to avoid errors in test environments
		var mgr := U_ServiceLocator.try_get_service(StringName("scene_manager")) as I_SceneManager
		if mgr != null:
			mgr.suppress_pause_for_current_frame()

		_trigger_transition()

## Interact-specific trigger guard (bypasses internal arm flag and zone flag)
func _can_trigger_interact() -> bool:
	if _pending_transition:
		return false

	if _cooldown_remaining > 0.0:
		return false

	# Guard against re-entry while a scene transition is underway
	var store = U_StateUtils.get_store(self)
	if store != null:
		var scene_state: Dictionary = store.get_slice(StringName("scene"))
		if scene_state.get("is_transitioning", false):
			return false

	# Also check SceneManager if available via ServiceLocator (Phase 10B-7: T141c)
	# Use try_get_service to avoid errors in test environments
	var mgr := U_ServiceLocator.try_get_service(StringName("scene_manager")) as I_SceneManager
	if mgr != null and mgr.is_transitioning():
		return false

	return true

## Hint to Scene Manager to preload target scene in background (Phase 8)
##
## Called when player enters trigger zone to start background loading of target scene.
## Non-blocking - scene loads in background while player is near door.
func _hint_preload_target_scene() -> void:
	# Find Scene Manager via ServiceLocator (Phase 10B-7: T141c)
	# Use try_get_service to avoid errors in test environments
	var scene_manager := U_ServiceLocator.try_get_service(StringName("scene_manager"))
	if scene_manager == null:
		# Scene Manager not found, skip hint (may not be implemented yet)
		return

	# Get target scene path from registry
	var scene_path: String = U_SceneRegistry.get_scene_path(target_scene_id)
	if scene_path.is_empty():
		return

	# Call Scene Manager's hint method (if available)
	var typed_manager := scene_manager as I_SceneManager
	if typed_manager != null:
		typed_manager.hint_preload_scene(scene_path)
