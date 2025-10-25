extends RefCounted
class_name U_ParticleSpawner

## Utility for spawning one-shot GPU particles with proper initialization
##
## Handles the complexity of:
## - Creating and configuring GPUParticles3D nodes
## - Setting up draw pass mesh and process material
## - Working around Godot GPU initialization timing bugs
## - Auto-cleanup after particle lifetime
## - Managing global effects container
##
## Usage:
##   var spawner := U_ParticleSpawner.new()
##   var container := U_ParticleSpawner.get_or_create_effects_container(get_tree())
##   spawner.spawn_particles(position, container, config, self)

## Configuration for particle spawning
class ParticleConfig:
	## Number of particles to emit
	var emission_count: int = 10
	## How long particles stay alive (seconds)
	var lifetime: float = 0.5
	## Scale of individual particles
	var scale: float = 0.1
	## Spread angle for emission (degrees)
	var spread_angle: float = 45.0
	## Initial velocity of particles
	var initial_velocity: float = 3.0
	## Offset from spawn position
	var spawn_offset: Vector3 = Vector3.DOWN
	## Optional custom process material
	var process_material: Material = null

	func _init(
		p_emission_count: int = 10,
		p_lifetime: float = 0.5,
		p_scale: float = 0.1,
		p_spread_angle: float = 45.0,
		p_initial_velocity: float = 3.0,
		p_spawn_offset: Vector3 = Vector3.DOWN,
		p_process_material: Material = null
	) -> void:
		emission_count = p_emission_count
		lifetime = p_lifetime
		scale = p_scale
		spread_angle = p_spread_angle
		initial_velocity = p_initial_velocity
		spawn_offset = p_spawn_offset
		process_material = p_process_material

## Spawn one-shot particles at the specified position
## caller_node is used for call_deferred (must be a Node in the scene tree)
## Returns the created GPUParticles3D node (for testing/inspection)
func spawn_particles(
	position: Vector3,
	container: Node3D,
	config: ParticleConfig,
	caller_node: Node
) -> GPUParticles3D:
	if container == null or caller_node == null:
		push_warning("U_ParticleSpawner: Cannot spawn particles - container or caller_node is null")
		return null

	if config == null:
		push_warning("U_ParticleSpawner: Cannot spawn particles - config is null")
		return null

	var particles := _create_particle_node(config)
	_setup_draw_pass(particles, config)
	_setup_process_material(particles, config)

	# Add to scene first (required before setting global_position)
	container.add_child(particles)

	# Set position after adding to tree
	particles.global_position = position + config.spawn_offset

	# Defer emission to work around Godot GPU initialization bug
	# See: https://github.com/godotengine/godot/issues/58778
	_defer_particle_activation(particles, caller_node)

	# Auto-cleanup after lifetime
	_schedule_cleanup(particles, config.lifetime, caller_node)

	return particles

## Create and configure the base GPUParticles3D node
func _create_particle_node(config: ParticleConfig) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = config.emission_count
	particles.lifetime = config.lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0  # All particles emit at once
	return particles

## Set up the draw pass mesh (required for particle visibility)
func _setup_draw_pass(particles: GPUParticles3D, config: ParticleConfig) -> void:
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(config.scale, config.scale)
	particles.draw_pass_1 = quad_mesh

## Set up the process material (physics/movement behavior)
func _setup_process_material(particles: GPUParticles3D, config: ParticleConfig) -> void:
	if config.process_material != null:
		particles.process_material = config.process_material
		return

	# Create default material
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.2
	material.direction = Vector3.UP
	material.spread = config.spread_angle
	material.initial_velocity_min = config.initial_velocity * 0.8
	material.initial_velocity_max = config.initial_velocity * 1.2
	material.gravity = Vector3(0, -9.8, 0)
	particles.process_material = material

## Defer particle activation to work around GPU buffer initialization bug
## Requires 2-frame delay for GPU to initialize before emitting
## The caller_node must implement:
##   func _u_particle_spawner_activate_frame1(particles: GPUParticles3D) -> void:
##       U_ParticleSpawner.activate_particles_frame2(particles, self)
##   func _u_particle_spawner_activate_frame2(particles: GPUParticles3D) -> void:
##       U_ParticleSpawner.activate_particles_final(particles)
func _defer_particle_activation(particles: GPUParticles3D, caller_node: Node) -> void:
	if caller_node == null:
		return

	# Start 2-frame deferred chain
	caller_node.call_deferred(&"_u_particle_spawner_activate_frame1", particles)

## Static helper methods for deferred activation chain

## Frame 1: Schedule second defer
static func activate_particles_frame2(particles: GPUParticles3D, caller_node: Node) -> void:
	if not is_instance_valid(particles) or caller_node == null:
		return
	caller_node.call_deferred(&"_u_particle_spawner_activate_frame2", particles)

## Frame 2: Actually activate particles
static func activate_particles_final(particles: GPUParticles3D) -> void:
	if not is_instance_valid(particles):
		return
	particles.emitting = true

## Schedule automatic cleanup after particle lifetime
func _schedule_cleanup(particles: GPUParticles3D, lifetime: float, caller_node: Node) -> void:
	var tree := caller_node.get_tree()
	if tree == null:
		return

	var cleanup_time: float = lifetime + 0.5  # Safety margin
	var timer: SceneTreeTimer = tree.create_timer(cleanup_time)
	timer.timeout.connect(particles.queue_free)

## Get or create the global effects container for particle systems
## Returns the container Node3D, or null if scene tree unavailable
static func get_or_create_effects_container(tree: SceneTree) -> Node3D:
	if tree == null:
		if OS.is_debug_build():
			push_warning("U_ParticleSpawner: Cannot get effects container - tree is null")
		return null

	# Look for existing container
	var containers: Array[Node] = tree.get_nodes_in_group("effects_container")
	if containers.size() > 0:
		return containers[0] as Node3D

	# Create new container
	var container := Node3D.new()
	container.name = "EffectsContainer"
	container.add_to_group("effects_container")

	# Add to current scene root
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		# Silently return null - this is expected in test environments
		return null

	current_scene.add_child(container)
	return container
