@icon("res://resources/editor_icons/system.svg")
extends BaseEventVFXSystem
class_name S_JumpParticlesSystem

const SETTINGS_TYPE := preload("res://scripts/ecs/resources/rs_jump_particles_settings.gd")
const PARTICLE_SPAWNER := preload("res://scripts/utils/u_particle_spawner.gd")

@export var settings: SETTINGS_TYPE

## Alias for EventVFXSystem.requests to maintain backward compatibility
var spawn_requests: Array:
	get:
		return requests

func get_event_name() -> StringName:
	return StringName("entity_jumped")

func create_request_from_payload(payload: Dictionary) -> Dictionary:
	return {
		"position": payload.get("position", Vector3.ZERO),
		"velocity": payload.get("velocity", Vector3.ZERO),
		"jump_force": payload.get("jump_force", 0.0),
	}

func process_tick(_delta: float) -> void:
	# Early exit if disabled or no settings
	if settings == null or not settings.enabled:
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
		settings.emission_count,
		settings.particle_lifetime,
		settings.particle_scale,
		settings.spread_angle,
		settings.initial_velocity,
		settings.spawn_offset,
		settings.particle_material
	)

# Helper methods required by ParticleSpawner for deferred activation
func _u_particle_spawner_activate_frame1(particles: GPUParticles3D) -> void:
	PARTICLE_SPAWNER.activate_particles_frame2(particles, self)

func _u_particle_spawner_activate_frame2(particles: GPUParticles3D) -> void:
	PARTICLE_SPAWNER.activate_particles_final(particles)
