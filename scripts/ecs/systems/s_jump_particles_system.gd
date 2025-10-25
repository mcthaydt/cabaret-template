@icon("res://resources/editor_icons/system.svg")
extends ECSSystem
class_name S_JumpParticlesSystem

const EVENT_NAME := StringName("entity_jumped")
const EVENT_BUS := preload("res://scripts/ecs/ecs_event_bus.gd")
const SETTINGS_TYPE := preload("res://scripts/ecs/resources/rs_jump_particles_settings.gd")

@export var settings: SETTINGS_TYPE

var spawn_requests: Array = []

var _unsubscribe_callable: Callable = Callable()

func _ready() -> void:
	super._ready()
	_subscribe()

func _exit_tree() -> void:
	_unsubscribe()
	spawn_requests.clear()

func process_tick(_delta: float) -> void:
	# Early exit if disabled or no settings
	if settings == null or not settings.enabled:
		spawn_requests.clear()
		return

	# Nothing to process
	if spawn_requests.size() == 0:
		return

	# Get or create the effects container
	var container: Node3D = _get_or_create_effects_container()
	if container == null:
		spawn_requests.clear()
		return

	# Spawn particles for each request
	for request in spawn_requests:
		var position: Vector3 = request.get("position", Vector3.ZERO)
		_spawn_jump_particles(position, container)

	# Clear processed requests
	spawn_requests.clear()

func _subscribe() -> void:
	_unsubscribe()
	spawn_requests.clear()
	_unsubscribe_callable = EVENT_BUS.subscribe(EVENT_NAME, Callable(self, "_on_entity_jumped"))

func _unsubscribe() -> void:
	if _unsubscribe_callable != Callable():
		_unsubscribe_callable.call()
		_unsubscribe_callable = Callable()

func _on_entity_jumped(event_data: Dictionary) -> void:
	var payload := _extract_payload(event_data)
	var request := {
		"position": payload.get("position", Vector3.ZERO),
		"velocity": payload.get("velocity", Vector3.ZERO),
		"timestamp": event_data.get("timestamp", 0.0),
		"jump_force": payload.get("jump_force", 0.0),
	}
	spawn_requests.append(request.duplicate(true))

func _extract_payload(event_data: Dictionary) -> Dictionary:
	if event_data.has("payload") and event_data["payload"] is Dictionary:
		return event_data["payload"]
	return {}

func _get_or_create_effects_container() -> Node3D:
	# Look for existing container in the scene tree
	var containers: Array[Node] = get_tree().get_nodes_in_group("effects_container")
	if containers.size() > 0:
		return containers[0] as Node3D

	# Create new container if none exists
	var container := Node3D.new()
	container.name = "EffectsContainer"
	container.add_to_group("effects_container")

	# Add to current scene root
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null

	current_scene.add_child(container)
	return container

func _activate_particles_deferred(particles: GPUParticles3D) -> void:
	# Verify particle still exists before activating
	if not is_instance_valid(particles):
		return

	# Set emitting to true after GPU has initialized
	particles.emitting = true

func _spawn_jump_particles(position: Vector3, container: Node3D) -> void:
	if settings == null:
		return

	# Create GPU particle node
	var particles := GPUParticles3D.new()
	particles.amount = settings.emission_count
	particles.lifetime = settings.particle_lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0 # All particles emit at once

	# CRITICAL FIX #1: Set draw pass mesh (required for visibility)
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(settings.particle_scale, settings.particle_scale)
	particles.draw_pass_1 = quad_mesh

	# CRITICAL FIX #2: Apply process material or create default
	if settings.particle_material != null:
		particles.process_material = settings.particle_material
	else:
		# Create basic default material so particles work out of the box
		var default_material := ParticleProcessMaterial.new()
		default_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		default_material.emission_sphere_radius = 0.2
		default_material.direction = Vector3.UP
		default_material.spread = settings.spread_angle
		default_material.initial_velocity_min = settings.initial_velocity * 0.8
		default_material.initial_velocity_max = settings.initial_velocity * 1.2
		default_material.gravity = Vector3(0, -9.8, 0)
		particles.process_material = default_material

	# Add to scene first (particle needs to be in tree before setting global transforms)
	container.add_child(particles)

	# Set position after adding to tree (required for global_position to work)
	# Apply spawn_offset from settings to adjust particle position
	particles.global_position = position + settings.spawn_offset

	# FIX: Defer emission by 2 frames to work around Godot bug with one_shot particles
	# GPU particle buffer needs time to initialize before emitting
	# See: https://github.com/godotengine/godot/issues/58778
	# Double call_deferred creates a 2-frame delay
	call_deferred("_activate_particles_call_deferred_again", particles)

	# Auto-cleanup after lifetime + safety margin
	var cleanup_time: float = settings.particle_lifetime + 0.5
	var timer: SceneTreeTimer = get_tree().create_timer(cleanup_time)
	timer.timeout.connect(particles.queue_free)

func _activate_particles_call_deferred_again(particles: GPUParticles3D) -> void:
	if is_instance_valid(particles):
		call_deferred("_activate_particles_deferred", particles)
