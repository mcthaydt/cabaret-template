@icon("res://resources/editor_icons/manager.svg")
class_name M_SpawnManager
extends Node

## M_SpawnManager - Player Spawn Point Management (Phase 12.1)
##
## Handles player entity spawning at designated spawn points in gameplay scenes.
## Extracted from M_SceneManager to achieve separation of concerns (3-manager architecture).
##
## Responsibilities:
## - Find and validate spawn points in loaded scenes
## - Position player entities at spawn points
## - Clear spawn point state after use
##
## Integration:
## - Discovers M_StateStore via "state_store" group
## - Called by M_SceneManager during scene transitions
## - Uses gameplay state to read target_spawn_point
##
## Architecture:
## - Scene-based manager (not autoload)
## - Added to "spawn_manager" group in _ready()
## - Discovered via get_tree().get_first_node_in_group("spawn_manager")

const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const U_SPAWN_REGISTRY := preload("res://scripts/scene_management/u_spawn_registry.gd")
const C_FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")

const SPAWN_CONDITION_ALWAYS := 0
const SPAWN_CONDITION_CHECKPOINT_ONLY := 1
const SPAWN_CONDITION_DISABLED := 2

const META_SPAWN_PHYSICS_FROZEN := StringName("_spawn_physics_frozen")

const SPAWN_HOVER_SNAP_MAX_DISTANCE := 0.75

## Internal references
var _state_store: M_STATE_STORE = null

func _ready() -> void:
	# Add to spawn_manager group for discovery
	add_to_group("spawn_manager")

	# Find state store via ServiceLocator (Phase 10B-7: T141c)
	# Gracefully handle missing store in test environments
	await get_tree().process_frame
	_state_store = U_ServiceLocator.try_get_service(StringName("state_store")) as M_STATE_STORE

	# Phase 10B (T133): Warn if M_StateStore missing for fail-fast feedback
	if _state_store == null:
		push_warning("M_SpawnManager: M_StateStore dependency not found. Ensure M_StateStore exists in scene tree and is in 'state_store' group")

## Spawn player at specified spawn point (T220)
##
## Validates spawn point exists and is a Node3D, finds player entity,
## positions player at spawn point (global position + rotation), and
## clears target_spawn_point from state.
##
## Parameters:
##   scene: Root node of the loaded scene
##   spawn_point_id: Name of the spawn point node (e.g., "sp_entrance_from_exterior")
##
## Returns:
##   true if spawn succeeded, false if validation failed or nodes not found
##
## Error Conditions:
##   - Scene is null → returns false
##   - Spawn point ID is empty → returns false
##   - Spawn point not found → push_error, returns false
##   - Spawn point is not Node3D → push_error, returns false
##   - Player entity not found → push_error, returns false
func spawn_player_at_point(scene: Node, spawn_point_id: StringName) -> bool:
	# Validate inputs
	if scene == null:
		push_error("M_SpawnManager: Cannot spawn player - scene is null")
		return false

	if spawn_point_id.is_empty():
		push_error("M_SpawnManager: Cannot spawn player - spawn_point_id is empty")
		return false

	# Get scene name for error messages
	var scene_name: String = scene.name if scene != null else "unknown"

	# Find spawn point node in scene (returns Node, not Node3D)
	var spawn_candidates: Array = []
	_find_nodes_by_name(scene, spawn_point_id, spawn_candidates)

	if spawn_candidates.is_empty():
		# If the requested id looks like a checkpoint id (cp_*), this likely
		# came from gameplay.last_checkpoint carried across scenes. In that
		# case, quietly fall back to scene default without treating it as an
		# error to avoid noisy logs in valid flows.
		var spawn_text := String(spawn_point_id)
		if spawn_text.begins_with("cp_"):
			_clear_target_spawn_point()
			return false

		push_error("M_SpawnManager: Spawn point '%s' not found in scene '%s'. Player will not be repositioned. Check spawn point naming and hierarchy." % [spawn_point_id, scene_name])
		_clear_target_spawn_point()
		return false

	var spawn_node: Node = spawn_candidates[0]

	# Validate spawn point is a Node3D (must check BEFORE casting)
	if not (spawn_node is Node3D):
		push_error("M_SpawnManager: Spawn point '%s' in scene '%s' is not a Node3D (found type: %s). Player cannot be positioned." % [spawn_point_id, scene_name, spawn_node.get_class()])
		_clear_target_spawn_point()
		return false

	# Cast to Node3D (safe - we validated above)
	var spawn_point: Node3D = spawn_node as Node3D

	# Find player entity in scene
	var player: Node3D = _find_player_entity(scene)
	if player == null:
		push_error("M_SpawnManager: Player entity not found in scene '%s' for spawn restoration. Expected node name starting with 'E_Player'." % scene_name)
		_clear_target_spawn_point()
		return false

	var ecs_body: CharacterBody3D = _find_character_body(player)
	var old_pos: Vector3 = player.global_position
	var old_rot: Vector3 = player.global_rotation
	var old_vel: Vector3 = Vector3.ZERO
	var old_is_on_floor: bool = false
	if ecs_body != null:
		old_vel = ecs_body.velocity
		old_is_on_floor = ecs_body.is_on_floor()

	# Position player at spawn point
	player.global_position = spawn_point.global_position
	player.global_rotation = spawn_point.global_rotation

	# Zero velocity and freeze physics to prevent bobble on spawn
	if ecs_body != null:
		# Zero velocity BEFORE freezing to prevent residual velocity from previous
		# scene causing bobble when physics resume.
		ecs_body.velocity = Vector3.ZERO

		# Disable physics processing - will be re-enabled by transition completion.
		# Note: ECS systems can still call move_and_slide(), so systems must also
		# respect META_SPAWN_PHYSICS_FROZEN.
		ecs_body.set_physics_process(false)

		# Store metadata so we know to re-enable it (root + body).
		player.set_meta(META_SPAWN_PHYSICS_FROZEN, true)
		ecs_body.set_meta(META_SPAWN_PHYSICS_FROZEN, true)

	# FIX: Reset floating component stable state to prevent stale ground detection
	# causing incorrect jump/gravity decisions on first frames after spawn
	_reset_floating_component_state(player)
	_snap_player_to_hover_height(player, ecs_body)

	# Publish player_spawned event for VFX systems (Phase 12.4)
	EVENT_BUS.publish(StringName("player_spawned"), {
		"position": spawn_point.global_position,
		"spawn_point_id": spawn_point_id,
		"player": player
	})

	# Clear target spawn point from state (one-time use)
	_clear_target_spawn_point()

	return true

## Find spawn point node by name in scene tree (T221)
##
## Searches scene tree recursively for node with matching name.
##
## Parameters:
##   scene: Root node to search from
##   spawn_point_id: Name of spawn point to find
##
## Returns:
##   Node3D if found, null otherwise
func _find_spawn_point(scene: Node, spawn_point_id: StringName) -> Node3D:
	# Search for spawn point marker (Node3D with matching name)
	var spawn_points: Array = []
	_find_nodes_by_name(scene, spawn_point_id, spawn_points)

	if spawn_points.is_empty():
		return null

	# Return first match (cast to Node3D, may be null if not Node3D)
	return spawn_points[0] as Node3D

## Find player entity in scene (T222)
##
## Searches for node with name starting with "E_Player" prefix.
##
## Parameters:
##   scene: Root node to search from
##
## Returns:
##   Node3D player entity if found, null otherwise
func _find_player_entity(scene: Node) -> Node3D:
	var players: Array = []
	_find_nodes_by_prefix(scene, "E_Player", players)

	if players.is_empty():
		return null

	return players[0] as Node3D

## Initialize scene camera (T223)
##
## Finds camera in "main_camera" group for potential blending.
## This method is a placeholder for future camera initialization needs.
##
## Parameters:
##   scene: Root node of the loaded scene
##
## Returns:
##   Camera3D if found, null otherwise (UI scenes don't need cameras)
func initialize_scene_camera(scene: Node) -> Camera3D:
	var cameras: Array = get_tree().get_nodes_in_group("main_camera")
	if cameras.is_empty():
		return null

	return cameras[0] as Camera3D

## Recursive helper to find nodes by exact name
##
## Searches scene tree recursively and appends all matches to results array.
##
## Parameters:
##   node: Current node to check
##   target_name: Name to search for
##   results: Array to append matches to (modified in-place)
func _find_nodes_by_name(node: Node, target_name: StringName, results: Array) -> void:
	if node.name == target_name:
		results.append(node)

	for child in node.get_children():
		_find_nodes_by_name(child, target_name, results)

## Recursive helper to find nodes by name prefix
##
## Searches scene tree recursively and appends all matches to results array.
##
## Parameters:
##   node: Current node to check
##   prefix: Name prefix to search for (e.g., "E_Player")
##   results: Array to append matches to (modified in-place)
func _find_nodes_by_prefix(node: Node, prefix: String, results: Array) -> void:
	if node.name.begins_with(prefix):
		results.append(node)

	for child in node.get_children():
		_find_nodes_by_prefix(child, prefix, results)

## Spawn player at last spawn point used (T255 - Phase 12.3a, T268 - Phase 12.3b)
##
## Priority order for spawn point selection:
##   1. target_spawn_point (set by C_SceneTriggerComponent for door transitions - current scene entry)
##   2. last_checkpoint (set by S_CheckpointSystem when player touches checkpoint - mid-scene)
##   3. sp_default (fallback if both above are empty)
##
## Used for death respawn: player respawns at the last meaningful location.
##
## Parameters:
##   scene: Root node of the current gameplay scene
##
## Returns:
##   true if spawn succeeded, false if validation failed
##
## Flow:
##   1. Check target_spawn_point first (where player entered current scene)
##   2. If empty, check last_checkpoint (mid-scene checkpoint)
##   3. If empty, fallback to "sp_default"
##   4. Call spawn_player_at_point() to position player
##   5. spawn_player_at_point() clears target_spawn_point automatically
func spawn_at_last_spawn(scene: Node) -> bool:
	# Validate scene
	if scene == null:
		push_error("M_SpawnManager: Cannot spawn - scene is null")
		return false

	# Refresh spawn metadata from the current scene's spawn points so
	# decisions are driven by scene-attached RS_SpawnMetadata resources.
	U_SPAWN_REGISTRY.reload_from_scene(scene)

	# Validate state store is ready (may not be during initial scene load)
	if _state_store == null:
		# Silently skip spawning if state store isn't ready yet (happens during boot)
		# Player will be at scene's default position, which is fine for initial load
		return false

	# Read spawn point from gameplay state
	var state: Dictionary = _state_store.get_state()
	var gameplay_state: Dictionary = state.get("gameplay", {})
	var last_checkpoint: StringName = gameplay_state.get("last_checkpoint", StringName(""))
	var target_spawn: StringName = gameplay_state.get("target_spawn_point", StringName(""))

	# Determine spawn source and id with priority, consulting spawn metadata:
	# 1) target_spawn_point (door entry) if allowed by metadata
	# 2) last_checkpoint (mid-scene checkpoint) if allowed by metadata
	# 3) sp_default (scene fallback, also gated by metadata)
	var used_last_checkpoint: bool = false
	var spawn_id: StringName = StringName("")

	if not target_spawn.is_empty() and _is_spawn_allowed(target_spawn, false):
		spawn_id = target_spawn
	elif not last_checkpoint.is_empty() and _is_spawn_allowed(last_checkpoint, true):
		spawn_id = last_checkpoint
		used_last_checkpoint = true
	else:
		spawn_id = StringName("sp_default")
		# Default spawn must also have metadata; missing metadata disables
		# the id (no more implicit "always allowed").
		if not _is_spawn_allowed(spawn_id, false):
			return false

	# Try primary spawn
	var ok: bool = await spawn_player_at_point(scene, spawn_id)

	# If checkpoint was chosen but is missing in this scene (e.g., carried over from another scene),
	# fall back to scene default to keep respawn reliable.
	if not ok and used_last_checkpoint:
		ok = await spawn_player_at_point(scene, StringName("sp_default"))

	return ok

## Check whether a spawn id is allowed based on metadata conditions.
##
## When no metadata exists for the given id, this returns true to
## preserve existing behaviour. When metadata is present, the
## SpawnCondition enum is interpreted as:
## - ALWAYS: always allowed
## - CHECKPOINT_ONLY: only allowed when selected from last_checkpoint
## - DISABLED: never allowed
func _is_spawn_allowed(spawn_id: StringName, used_last_checkpoint: bool) -> bool:
	if spawn_id.is_empty():
		return false

	var metadata: Dictionary = U_SPAWN_REGISTRY.get_spawn(spawn_id)
	if metadata.is_empty():
		# No metadata configured; disable this spawn id. All spawn
		# selection should be driven by scene-attached metadata.
		return false

	var condition: int = int(metadata.get("condition", SPAWN_CONDITION_ALWAYS))

	if condition == SPAWN_CONDITION_DISABLED:
		return false

	if condition == SPAWN_CONDITION_CHECKPOINT_ONLY and not used_last_checkpoint:
		return false

	return true

## Clear target spawn point from gameplay state
##
## Dispatches action to clear spawn point field in state store.
## Called after successful spawn or when spawn fails.
func _clear_target_spawn_point() -> void:
	if _state_store == null:
		return

	# Dispatch action to clear spawn point
	var clear_action: Dictionary = U_GAMEPLAY_ACTIONS.set_target_spawn_point(StringName(""))
	_state_store.dispatch(clear_action)

## Reset floating component stable state on spawn
##
## Clears the hysteresis counters and stable ground state to prevent stale
## ground detection from causing incorrect jump/gravity decisions on spawn.
## Uses reset_recent_support() which clears:
## - is_supported
## - grounded_stable
## - _consecutive_grounded_frames
## - _consecutive_airborne_frames
## - _last_support_time (set to expire grace period)
func _reset_floating_component_state(player: Node3D) -> void:
	if player == null:
		return

	# Search for C_FloatingComponent in player's children
	var floating := _find_floating_component(player)
	if floating == null:
		return

	# Reset stable state so ground detection starts fresh
	var current_time: float = U_ECS_UTILS.get_current_time()
	var grace_time: float = 0.1  # Match typical coyote time
	floating.reset_recent_support(current_time, grace_time)

## Find C_FloatingComponent in entity's children recursively
func _find_floating_component(node: Node) -> C_FLOATING_COMPONENT:
	if node is C_FLOATING_COMPONENT:
		return node as C_FLOATING_COMPONENT

	for child in node.get_children():
		var found: C_FLOATING_COMPONENT = _find_floating_component(child)
		if found != null:
			return found

	return null

func _find_character_body(node: Node) -> CharacterBody3D:
	if node is CharacterBody3D:
		return node as CharacterBody3D

	for child in node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var found := _find_character_body(child_node)
		if found != null:
			return found

	return null

class SpawnSupportInfo:
	var has_hit: bool = false
	var distance: float = 0.0
	var normal: Vector3 = Vector3.ZERO
	var hit_count: int = 0
	var total_rays: int = 0

func _snap_player_to_hover_height(player: Node3D, ecs_body: CharacterBody3D) -> void:
	if player == null:
		return

	var floating := _find_floating_component(player)
	if floating == null or floating.settings == null:
		return

	var rays: Array = floating.get_raycast_nodes()
	if rays.is_empty():
		return

	var support: SpawnSupportInfo = _collect_spawn_support_data(rays)
	if not support.has_hit:
		return

	var normal: Vector3 = support.normal
	if normal.length() == 0.0:
		normal = Vector3.UP
	normal = normal.normalized()

	var hover_height: float = floating.settings.hover_height
	var height_error: float = hover_height - support.distance
	var tolerance: float = max(floating.settings.height_tolerance, 0.0)
	if abs(height_error) <= tolerance:
		return

	# Clamp snap to avoid large teleports when ground is far/missing.
	height_error = clamp(height_error, -SPAWN_HOVER_SNAP_MAX_DISTANCE, SPAWN_HOVER_SNAP_MAX_DISTANCE)
	player.global_position += normal * height_error

	if ecs_body != null:
		ecs_body.velocity = Vector3.ZERO

func _collect_spawn_support_data(rays: Array) -> SpawnSupportInfo:
	var data: SpawnSupportInfo = SpawnSupportInfo.new()
	var min_distance: float = INF
	var normal_sum: Vector3 = Vector3.ZERO
	var hit_count: int = 0
	data.total_rays = rays.size()

	for ray in rays:
		if ray == null:
			continue

		if ray.has_method("force_raycast_update"):
			ray.force_raycast_update()

		if not ray.is_colliding():
			continue

		data.has_hit = true
		hit_count += 1

		var origin: Vector3 = (ray as Node3D).global_transform.origin
		var point: Vector3 = ray.get_collision_point()
		var distance: float = origin.distance_to(point)
		if distance < min_distance:
			min_distance = distance

		normal_sum += ray.get_collision_normal()

	if data.has_hit:
		data.distance = min_distance if min_distance != INF else 0.0
		if hit_count > 0:
			data.normal = normal_sum / hit_count
		data.hit_count = hit_count

	return data
