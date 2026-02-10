@icon("res://assets/editor_icons/icn_system.svg")
extends BaseEventVFXSystem
class_name S_SpawnParticlesSystem

## Spawn Particles System (Phase 12.4)
##
## Creates particle effects when player spawns at spawn points.
## Listens for "player_spawned" events from M_SpawnManager.

const PARTICLE_SPAWNER := preload("res://scripts/utils/u_particle_spawner.gd")

@export var enabled: bool = true
@export var emission_count: int = 20
@export var particle_lifetime: float = 0.8
@export var particle_scale: float = 0.3
@export var spread_angle: float = 45.0
@export var initial_velocity: float = 3.0
@export var spawn_offset: Vector3 = Vector3(0, 0.5, 0)

func get_event_name() -> StringName:
	return StringName("player_spawned")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	return {
		"position": payload.get("position", Vector3.ZERO),
		"spawn_point_id": payload.get("spawn_point_id", StringName("")),
	}

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
