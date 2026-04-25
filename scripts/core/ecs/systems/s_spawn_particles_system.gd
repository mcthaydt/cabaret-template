@icon("res://assets/core/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_SpawnParticlesSystem

## Spawn Particles System (Phase 12.4)
##
## Creates particle effects when player spawns at spawn points.
## Subscribes to Redux ACTION_PLAYER_SPAWNED via action_dispatched signal
## per channel taxonomy (docs/architecture/adr/0001-channel-taxonomy.md).

const PARTICLE_SPAWNER := preload("res://scripts/core/utils/u_particle_spawner.gd")
const U_SPAWN_ACTIONS := preload("res://scripts/core/state/actions/u_spawn_actions.gd")

@export var enabled: bool = true
@export var emission_count: int = 20
@export var particle_lifetime: float = 0.8
@export var particle_scale: float = 0.3
@export var spread_angle: float = 45.0
@export var initial_velocity: float = 3.0
@export var spawn_offset: Vector3 = Vector3(0, 0.5, 0)

var requests: Array = []
var _store: Node = null

func _ready() -> void:
	super._ready()
	_subscribe_to_actions()

func _exit_tree() -> void:
	_unsubscribe_from_actions()
	requests.clear()

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.VFX

func _subscribe_to_actions() -> void:
	_unsubscribe_from_actions()
	var store_variant: Variant = U_ServiceLocator.try_get_service(StringName("state_store"))
	if store_variant == null:
		return
	var store: Node = store_variant as Node
	if store == null or not store.has_signal("action_dispatched"):
		return
	_store = store
	_store.action_dispatched.connect(_on_action_dispatched)

func _unsubscribe_from_actions() -> void:
	if _store != null and is_instance_valid(_store) and _store.has_signal("action_dispatched"):
		_store.action_dispatched.disconnect(_on_action_dispatched)
	_store = null

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: StringName = action.get("type", StringName(""))
	if action_type != U_SPAWN_ACTIONS.ACTION_PLAYER_SPAWNED:
		return
	var request: Dictionary = {
		"position": action.get("position", Vector3.ZERO),
		"spawn_point_id": action.get("spawn_point_id", StringName("")),
	}
	if not request.has("timestamp"):
		request["timestamp"] = 0.0
	requests.append(request.duplicate(true))

func process_tick(__delta: float) -> void:
	# Early exit if disabled
	if not enabled:
		requests.clear()
		return

	# Nothing to process
	if requests.size() == 0:
		return

	# Get or create the effects container
	var container := PARTICLE_SPAWNER.get_or_create_effects_container(get_tree())
	if container == null:
		requests.clear()
		return

	# Create spawner and config
	var spawner := PARTICLE_SPAWNER.new()
	var config := _create_particle_config()

	# Spawn particles for each request
	for request in requests:
		var position: Vector3 = request.get("position", Vector3.ZERO)
		spawner.spawn_particles(position, container, config, self)

	# Clear processed requests
	requests.clear()

func _create_particle_config() -> PARTICLE_SPAWNER.ParticleConfig:
	return PARTICLE_SPAWNER.ParticleConfig.new(
		emission_count,
		particle_lifetime,
		particle_scale,
		spread_angle,
		initial_velocity,
		spawn_offset,
		null  # Use default material
	)

# Helper methods required by ParticleSpawner for deferred activation
func _u_particle_spawner_activate_frame1(particles: GPUParticles3D) -> void:
	PARTICLE_SPAWNER.activate_particles_frame2(particles, self)

func _u_particle_spawner_activate_frame2(particles: GPUParticles3D) -> void:
	PARTICLE_SPAWNER.activate_particles_final(particles)