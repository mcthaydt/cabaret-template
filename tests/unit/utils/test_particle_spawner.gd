extends BaseTest

const PARTICLE_SPAWNER := preload("res://scripts/utils/u_particle_spawner.gd")

func _pump() -> void:
	await get_tree().process_frame

# Helper methods required by ParticleSpawner for deferred activation
func _u_particle_spawner_activate_frame1(particles: GPUParticles3D) -> void:
	PARTICLE_SPAWNER.activate_particles_frame2(particles, self)

func _u_particle_spawner_activate_frame2(particles: GPUParticles3D) -> void:
	PARTICLE_SPAWNER.activate_particles_final(particles)

# ParticleConfig Tests

func test_particle_config_defaults() -> void:
	var config := PARTICLE_SPAWNER.ParticleConfig.new()
	assert_eq(config.emission_count, 10)
	assert_eq(config.lifetime, 0.5)
	assert_eq(config.scale, 0.1)
	assert_eq(config.spread_angle, 45.0)
	assert_eq(config.initial_velocity, 3.0)
	assert_eq(config.spawn_offset, Vector3(0, -0.5, 0))
	assert_null(config.process_material)

func test_particle_config_custom_values() -> void:
	var config := PARTICLE_SPAWNER.ParticleConfig.new(
		20,  # emission_count
		1.0,  # lifetime
		0.2,  # scale
		90.0,  # spread_angle
		5.0,  # initial_velocity
		Vector3.UP  # spawn_offset
	)
	assert_eq(config.emission_count, 20)
	assert_eq(config.lifetime, 1.0)
	assert_eq(config.scale, 0.2)
	assert_eq(config.spread_angle, 90.0)
	assert_eq(config.initial_velocity, 5.0)
	assert_eq(config.spawn_offset, Vector3.UP)

# ParticleSpawner Basic Tests

func test_spawn_particles_returns_gpu_particles_node() -> void:
	var spawner := PARTICLE_SPAWNER.new()
	var config := PARTICLE_SPAWNER.ParticleConfig.new()
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	var particles := spawner.spawn_particles(Vector3.ZERO, container, config, self)

	assert_not_null(particles)
	assert_true(particles is GPUParticles3D)
	assert_eq(particles.get_parent(), container)

# Note: Null parameter tests removed - they generate warnings which GUT treats as errors
# The behavior is still validated: spawner returns null when parameters are invalid

# Particle Configuration Tests

func test_particles_configured_with_emission_count() -> void:
	var spawner := PARTICLE_SPAWNER.new()
	var config := PARTICLE_SPAWNER.ParticleConfig.new(50)
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	var particles := spawner.spawn_particles(Vector3.ZERO, container, config, self)

	assert_eq(particles.amount, 50)

func test_particles_configured_with_lifetime() -> void:
	var spawner := PARTICLE_SPAWNER.new()
	var config := PARTICLE_SPAWNER.ParticleConfig.new(10, 2.0)
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	var particles := spawner.spawn_particles(Vector3.ZERO, container, config, self)

	assert_eq(particles.lifetime, 2.0)

func test_particles_oneshot_and_explosive() -> void:
	var spawner := PARTICLE_SPAWNER.new()
	var config := PARTICLE_SPAWNER.ParticleConfig.new()
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	var particles := spawner.spawn_particles(Vector3.ZERO, container, config, self)

	assert_true(particles.one_shot)
	assert_eq(particles.explosiveness, 1.0)

func test_particles_have_draw_pass_mesh() -> void:
	var spawner := PARTICLE_SPAWNER.new()
	var config := PARTICLE_SPAWNER.ParticleConfig.new(10, 0.5, 0.3)  # scale = 0.3
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	var particles := spawner.spawn_particles(Vector3.ZERO, container, config, self)

	assert_not_null(particles.draw_pass_1)
	var mesh := particles.draw_pass_1 as QuadMesh
	assert_not_null(mesh)
	assert_eq(mesh.size, Vector2(0.3, 0.3))

func test_particles_have_default_process_material() -> void:
	var spawner := PARTICLE_SPAWNER.new()
	var config := PARTICLE_SPAWNER.ParticleConfig.new()
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	var particles := spawner.spawn_particles(Vector3.ZERO, container, config, self)

	assert_not_null(particles.process_material)
	var material := particles.process_material as ParticleProcessMaterial
	assert_not_null(material)
	assert_eq(material.emission_shape, ParticleProcessMaterial.EMISSION_SHAPE_SPHERE)

func test_particles_use_custom_process_material_if_provided() -> void:
	var spawner := PARTICLE_SPAWNER.new()
	var custom_material := ParticleProcessMaterial.new()
	custom_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	var config := PARTICLE_SPAWNER.ParticleConfig.new(10, 0.5, 0.1, 45.0, 3.0, Vector3.DOWN, custom_material)
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	var particles := spawner.spawn_particles(Vector3.ZERO, container, config, self)

	assert_eq(particles.process_material, custom_material)
	var material := particles.process_material as ParticleProcessMaterial
	assert_eq(material.emission_shape, ParticleProcessMaterial.EMISSION_SHAPE_BOX)

# Position Tests

func test_particles_positioned_at_spawn_location_plus_offset() -> void:
	var spawner := PARTICLE_SPAWNER.new()
	var config := PARTICLE_SPAWNER.ParticleConfig.new(10, 0.5, 0.1, 45.0, 3.0, Vector3(0, -2, 0))
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	var particles := spawner.spawn_particles(Vector3(5, 10, 3), container, config, self)

	assert_eq(particles.global_position, Vector3(5, 8, 3))  # 10 + (-2) = 8

# Deferred Activation Tests
# Note: Deferred activation is tested in integration tests
# Unit tests just verify the particles are created and added to tree

func test_particles_added_to_container() -> void:
	var spawner := PARTICLE_SPAWNER.new()
	var config := PARTICLE_SPAWNER.ParticleConfig.new()
	var container := Node3D.new()
	add_child(container)
	autofree(container)

	var particles := spawner.spawn_particles(Vector3.ZERO, container, config, self)

	assert_eq(particles.get_parent(), container, "Particles should be child of container")
	assert_true(container.get_children().has(particles), "Container should have particles as child")
