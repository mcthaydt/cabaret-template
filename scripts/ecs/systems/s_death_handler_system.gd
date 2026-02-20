@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_DeathHandlerSystem

const PLAYER_RAGDOLL := preload("res://scenes/prefabs/prefab_player_ragdoll.tscn")

var _event_unsubscribes: Array[Callable] = []
var _ragdoll_spawned: Dictionary = {}  # entity_id -> bool
var _ragdoll_instances: Dictionary = {}  # entity_id -> WeakRef
var _entity_refs: Dictionary = {}  # entity_id -> WeakRef
var _entity_original_visibility: Dictionary = {}  # entity_id -> bool
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func on_configured() -> void:
	_subscribe_events()

func process_tick(__delta: float) -> void:
	# Event-driven system.
	pass

func _subscribe_events() -> void:
	_event_unsubscribes.append(U_ECSEventBus.subscribe(
		U_ECSEventNames.EVENT_ENTITY_DEATH_REQUESTED,
		_on_entity_death_requested
	))
	_event_unsubscribes.append(U_ECSEventBus.subscribe(
		U_ECSEventNames.EVENT_ENTITY_RESPAWN_REQUESTED,
		_on_entity_respawn_requested
	))

func _on_entity_death_requested(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var entity_id: String = _resolve_entity_id(payload)
	if entity_id.is_empty():
		push_warning("S_DeathHandlerSystem: entity_death_requested missing required payload.entity_id")
		return

	if _ragdoll_spawned.get(entity_id, false):
		return

	_spawn_ragdoll(entity_id, payload)
	_ragdoll_spawned[entity_id] = true

func _on_entity_respawn_requested(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	var entity_id: String = _resolve_entity_id(payload)
	if entity_id.is_empty():
		push_warning("S_DeathHandlerSystem: entity_respawn_requested missing required payload.entity_id")
		return

	_restore_entity_state(entity_id, payload)

func _spawn_ragdoll(entity_id: String, payload: Dictionary) -> void:
	if PLAYER_RAGDOLL == null:
		return

	var health_component: C_HealthComponent = payload.get("health_component", null) as C_HealthComponent
	var entity_root: Node3D = payload.get("entity_root", null) as Node3D
	var body: CharacterBody3D = payload.get("body", null) as CharacterBody3D

	if entity_root == null and health_component != null:
		entity_root = U_ECSUtils.find_entity_root(health_component) as Node3D
		if entity_root == null:
			entity_root = health_component.get_parent() as Node3D
	if body == null and health_component != null:
		body = health_component.get_character_body()

	if entity_root == null and body != null:
		entity_root = U_ECSUtils.find_entity_root(body, true) as Node3D
		if entity_root == null:
			entity_root = body.get_parent() as Node3D

	if entity_root == null:
		return

	var parent: Node = entity_root.get_parent()
	if parent == null:
		return

	var ragdoll_scene: PackedScene = PLAYER_RAGDOLL as PackedScene
	if ragdoll_scene == null:
		return

	var ragdoll: RigidBody3D = ragdoll_scene.instantiate() as RigidBody3D
	if ragdoll == null:
		return

	var source_transform: Transform3D = entity_root.global_transform
	if body != null and is_instance_valid(body):
		source_transform = body.global_transform

	parent.add_child(ragdoll)
	ragdoll.global_transform = source_transform
	ragdoll.linear_velocity = Vector3(
		_rng.randf_range(-4.0, 4.0),
		_rng.randf_range(4.0, 6.0),
		_rng.randf_range(-4.0, 4.0)
	)
	ragdoll.angular_velocity = Vector3(
		_rng.randf_range(-6.0, 6.0),
		_rng.randf_range(-3.0, 3.0),
		_rng.randf_range(-6.0, 6.0)
	)

	_entity_refs[entity_id] = weakref(entity_root)
	_entity_original_visibility[entity_id] = entity_root.visible
	entity_root.visible = false
	_ragdoll_instances[entity_id] = weakref(ragdoll)

func _restore_entity_state(entity_id: String, payload: Dictionary = {}) -> void:
	var ragdoll_ref_candidate: Variant = _ragdoll_instances.get(entity_id, null)
	if ragdoll_ref_candidate is WeakRef:
		var ragdoll_ref: WeakRef = ragdoll_ref_candidate
		var ragdoll: RigidBody3D = ragdoll_ref.get_ref() as RigidBody3D
		if ragdoll != null and is_instance_valid(ragdoll):
			ragdoll.queue_free()
	_ragdoll_instances.erase(entity_id)

	var entity: Node3D = null
	var entity_ref_candidate: Variant = _entity_refs.get(entity_id, null)
	if entity_ref_candidate is WeakRef:
		var entity_ref: WeakRef = entity_ref_candidate
		entity = entity_ref.get_ref() as Node3D
	if entity == null:
		entity = payload.get("entity_root", null) as Node3D
	if entity != null and is_instance_valid(entity):
		var was_visible: bool = bool(_entity_original_visibility.get(entity_id, true))
		entity.visible = was_visible

	_entity_refs.erase(entity_id)
	_entity_original_visibility.erase(entity_id)
	_ragdoll_spawned.erase(entity_id)

func get_ragdoll_for_entity(entity_id: StringName) -> RigidBody3D:
	var key: String = String(entity_id)
	# BaseECSEntity strips the `E_` prefix when auto-generating entity_ids from node names.
	# Accept either canonical ids (`player`) or scene node-style ids (`E_Player`) in callers.
	if key.begins_with("E_"):
		key = key.substr(2).to_lower()
	var ragdoll_ref_candidate: Variant = _ragdoll_instances.get(key, null)
	if ragdoll_ref_candidate is WeakRef:
		var ragdoll_ref: WeakRef = ragdoll_ref_candidate
		return ragdoll_ref.get_ref() as RigidBody3D
	return null

func _resolve_entity_id(payload: Dictionary) -> String:
	var entity_id_value: Variant = payload.get("entity_id", "")
	if entity_id_value is StringName:
		return String(entity_id_value)
	if entity_id_value is String:
		return entity_id_value
	return ""

func _exit_tree() -> void:
	for unsubscribe in _event_unsubscribes:
		if unsubscribe != null and unsubscribe is Callable and (unsubscribe as Callable).is_valid():
			(unsubscribe as Callable).call()
	_event_unsubscribes.clear()
